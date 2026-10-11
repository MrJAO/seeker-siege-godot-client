extends Node

signal wallet_connected(address: String)
signal wallet_disconnected
signal wallet_connect_failed

var wallet_is_connected: bool = false
var wallet_address: String = ""

var _adapter: WalletAdapter = null

var _connecting: bool = false
var _connect_success: bool = false
var _connect_failed: bool = false

var _sign_result: PackedByteArray = PackedByteArray()
var _sign_failed: bool = false

var _tx_blockhash_ok: bool = false
var _tx_blockhash_failed: bool = false
var _tx_blockhash_result: Dictionary = {}
var _tx_signed: bool = false
var _tx_sign_failed: bool = false
var _tx_send_result: Variant = null
var _tx_send_done: bool = false

const CONNECT_TIMEOUT_SECONDS: float = 60.0
const POLL_INTERVAL_SECONDS: float = 0.3
const POLL_MIN_KEY_LENGTH: int = 20
const CANCEL_GRACE_SECONDS: float = 1.5

var _current_operation: String = ""
var _focus_generation: int = 0

func _ready() -> void:
	_create_adapter()

func _create_adapter() -> void:
	_adapter = WalletAdapter.new()
	add_child(_adapter)
	_adapter.mobile_identity_name = "Seeker Siege"
	_adapter.mobile_identity_uri = "https://seekersiege.xyz"
	_adapter.connection_established.connect(_on_connection_established)
	_adapter.connection_failed.connect(_on_connection_failed)
	_adapter.message_signed.connect(_on_message_signed)
	_adapter.signing_failed.connect(_on_signing_failed)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focus_generation += 1
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if _current_operation != "":
			_check_for_cancellation()

func _check_for_cancellation() -> void:
	var gen: int = _focus_generation
	await get_tree().create_timer(CANCEL_GRACE_SECONDS).timeout
	if gen != _focus_generation:
		return

	if _current_operation == "connect" and _connecting and not _connect_success and not _connect_failed:
		_connect_failed = true
	elif _current_operation == "sign" and _sign_result.is_empty() and not _sign_failed:
		_sign_failed = true

func _clear_native_plugin_state() -> void:
	if not Engine.has_singleton("WalletAdapterAndroid"):
		return
	var plugin = Engine.get_singleton("WalletAdapterAndroid")
	if plugin.has_method("clearStateFullReset"):
		plugin.call("clearStateFullReset")
	elif plugin.has_method("clearState"):
		plugin.call("clearState")

func _recreate_adapter() -> void:
	if _adapter != null:
		var old_adapter = _adapter
		_adapter = null
		remove_child(old_adapter)
		old_adapter.queue_free()
		await get_tree().process_frame
	_create_adapter()

func connect_wallet() -> bool:
	if _connecting:
		while _connecting:
			await get_tree().create_timer(POLL_INTERVAL_SECONDS).timeout
		return _connect_success

	_connecting = true
	_connect_success = false
	_connect_failed = false
	_current_operation = "connect"

	if OS.get_name() == "Android":
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR)

	_clear_native_plugin_state()
	await _recreate_adapter()

	var pre_connect_key: String = _extract_pubkey_string(_adapter.get_connected_key())
	_adapter.connect_wallet()

	var elapsed: float = 0.0
	while not _connect_success and not _connect_failed and elapsed < CONNECT_TIMEOUT_SECONDS:
		await get_tree().create_timer(POLL_INTERVAL_SECONDS).timeout
		elapsed += POLL_INTERVAL_SECONDS

		var poll_key: String = _extract_pubkey_string(_adapter.get_connected_key())
		if poll_key.length() > POLL_MIN_KEY_LENGTH and poll_key != pre_connect_key:
			wallet_address = poll_key
			wallet_is_connected = true
			_connect_success = true
			emit_signal("wallet_connected", wallet_address)

	if OS.get_name() == "Android":
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)

	_current_operation = ""
	_connecting = false

	if not _connect_success:
		emit_signal("wallet_connect_failed")

	return _connect_success

func _on_connection_established() -> void:
	if _connect_success:
		return
	var key: String = _extract_pubkey_string(_adapter.get_connected_key())
	if key.length() <= POLL_MIN_KEY_LENGTH:
		return
	wallet_address = key
	wallet_is_connected = true
	_connect_success = true
	emit_signal("wallet_connected", wallet_address)

func _on_connection_failed() -> void:
	wallet_is_connected = false
	_connect_failed = true

func disconnect_wallet() -> void:
	_clear_native_plugin_state()
	wallet_is_connected = false
	wallet_address = ""
	emit_signal("wallet_disconnected")

func _extract_pubkey_string(key_obj) -> String:
	if key_obj == null:
		return ""
	var raw: String = str(key_obj)
	var start: int = raw.find(":")
	var end: int = raw.rfind("]")
	if start == -1 or end == -1 or end <= start:
		return ""
	var inner: String = raw.substr(start + 1, end - start - 1)
	return _normalize_pubkey_string(inner)

func _normalize_pubkey_string(raw: String) -> String:
	if raw.is_empty():
		return raw
	if not (raw.contains("=") or raw.contains("+") or raw.contains("/")):
		return raw
	push_warning("WalletManager: address looked base64-encoded, converting - %s" % raw)
	var decoded: PackedByteArray = Marshalls.base64_to_raw(raw)
	if decoded.size() != 32:
		push_warning("WalletManager: unexpected byte length after decode (%d, expected 32) - using raw value" % decoded.size())
		return raw
	var pk: Pubkey = Pubkey.new_from_bytes(decoded)
	return pk.to_string()

func sign_message(text: String) -> PackedByteArray:
	_sign_result = PackedByteArray()
	_sign_failed = false
	_current_operation = "sign"

	if OS.get_name() == "Android":
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR)

	_adapter.sign_text_message(text)

	var elapsed: float = 0.0
	while _sign_result.is_empty() and not _sign_failed and elapsed < CONNECT_TIMEOUT_SECONDS:
		await get_tree().create_timer(POLL_INTERVAL_SECONDS).timeout
		elapsed += POLL_INTERVAL_SECONDS

	if OS.get_name() == "Android":
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)

	_current_operation = ""
	return _sign_result

func _on_message_signed(signature) -> void:
	if signature is PackedByteArray:
		_sign_result = signature
	elif signature is Array:
		var bytes := PackedByteArray()
		for b in signature:
			bytes.append(int(b))
		_sign_result = bytes
	else:
		push_warning("WalletManager: unexpected message_signed signal payload type")

func _on_signing_failed() -> void:
	_sign_failed = true

# Sign SOL transaction
func sign_and_send_sol_transfer(destinations: Array, rpc_url: String) -> Dictionary:
	if not wallet_is_connected:
		return {"ok": false, "error": "not_connected"}
	if not Engine.has_singleton("WalletAdapterAndroid"):
		return {"ok": false, "error": "no_android_plugin"}
	var plugin = Engine.get_singleton("WalletAdapterAndroid")

	_current_operation = "transaction"
	if OS.get_name() == "Android":
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR)

	var payer_pubkey: Pubkey = _adapter.get_connected_key()
	var tx := Transaction.new()
	add_child(tx)
	tx.set_payer(_adapter)
	for dest in destinations:
		var dest_pubkey: Pubkey = Pubkey.new_from_string(String(dest.wallet))
		tx.add_instruction(SystemProgram.transfer(payer_pubkey, dest_pubkey, int(dest.lamports)))
	tx.url_override = rpc_url

	_tx_blockhash_ok = false
	_tx_blockhash_failed = false
	tx.blockhash_updated.connect(_on_tx_blockhash_updated, CONNECT_ONE_SHOT)
	tx.blockhash_update_failed.connect(_on_tx_blockhash_failed_handler, CONNECT_ONE_SHOT)
	tx.update_latest_blockhash()

	var elapsed: float = 0.0
	while not _tx_blockhash_ok and not _tx_blockhash_failed and elapsed < CONNECT_TIMEOUT_SECONDS:
		await get_tree().create_timer(POLL_INTERVAL_SECONDS).timeout
		elapsed += POLL_INTERVAL_SECONDS

	if not _tx_blockhash_ok:
		tx.queue_free()
		_finish_transaction_op()
		return {"ok": false, "error": "blockhash_failed"}

	var tx_bytes: PackedByteArray = tx.serialize()

	plugin.call("signTransaction", tx_bytes)

	elapsed = 0.0
	var status: int = 0
	while status == 0 and elapsed < CONNECT_TIMEOUT_SECONDS:
		await get_tree().create_timer(POLL_INTERVAL_SECONDS).timeout
		elapsed += POLL_INTERVAL_SECONDS
		status = plugin.call("getSigningStatus")

	if status != 1:
		tx.queue_free()
		_finish_transaction_op()
		return {"ok": false, "error": "signing_failed_or_timeout"}

	var raw_response: PackedByteArray = plugin.call("getMessageSignature")
	plugin.call("clearStateFullReset")
	tx.queue_free()

	if raw_response.size() < 65:
		_finish_transaction_op()
		return {"ok": false, "error": "signed_response_too_small"}

	var signed_tx = Transaction.new_from_bytes(raw_response)
	add_child(signed_tx)
	signed_tx.url_override = rpc_url

	_tx_send_done = false
	_tx_send_result = null
	signed_tx.transaction_response_received.connect(_on_tx_send_response, CONNECT_ONE_SHOT)
	signed_tx.send()

	elapsed = 0.0
	while not _tx_send_done and elapsed < CONNECT_TIMEOUT_SECONDS:
		await get_tree().create_timer(POLL_INTERVAL_SECONDS).timeout
		elapsed += POLL_INTERVAL_SECONDS

	signed_tx.queue_free()
	_finish_transaction_op()

	if typeof(_tx_send_result) == TYPE_DICTIONARY and _tx_send_result.has("result"):
		return {"ok": true, "signature": String(_tx_send_result.result)}

	return {"ok": false, "error": "broadcast_failed_or_timeout", "raw": _tx_send_result}

# Sign SKR transaction
func sign_and_send_skr_transfer(prepare_data: Dictionary, rpc_url: String) -> Dictionary:
	if not wallet_is_connected:
		return {"ok": false, "error": "not_connected"}
	if not Engine.has_singleton("WalletAdapterAndroid"):
		return {"ok": false, "error": "no_android_plugin"}
	var plugin = Engine.get_singleton("WalletAdapterAndroid")

	_current_operation = "transaction"
	if OS.get_name() == "Android":
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR)

	var payer_pubkey: Pubkey = _adapter.get_connected_key()
	var mint_pubkey: Pubkey = Pubkey.new_from_string(String(prepare_data.mintAddress))
	var source_ata: Pubkey = Pubkey.new_from_string(String(prepare_data.buyerAta))
	var decimals: int = int(prepare_data.decimals)

	var tx := Transaction.new()
	add_child(tx)
	tx.set_payer(_adapter)

	var seller_ata: Pubkey = Pubkey.new_from_string(String(prepare_data.sellerAta))
	var seller_amount: int = int(prepare_data.sellerAmountBaseUnits)
	tx.add_instruction(TokenProgram.transfer_checked(source_ata, mint_pubkey, seller_ata, payer_pubkey, seller_amount, decimals))

	var treasury_ata: Pubkey = Pubkey.new_from_string(String(prepare_data.treasuryAta))
	var treasury_amount: int = int(prepare_data.treasuryAmountBaseUnits)
	tx.add_instruction(TokenProgram.transfer_checked(source_ata, mint_pubkey, treasury_ata, payer_pubkey, treasury_amount, decimals))

	tx.url_override = rpc_url

	_tx_blockhash_ok = false
	_tx_blockhash_failed = false
	tx.blockhash_updated.connect(_on_tx_blockhash_updated, CONNECT_ONE_SHOT)
	tx.blockhash_update_failed.connect(_on_tx_blockhash_failed_handler, CONNECT_ONE_SHOT)
	tx.update_latest_blockhash()

	var elapsed: float = 0.0
	while not _tx_blockhash_ok and not _tx_blockhash_failed and elapsed < CONNECT_TIMEOUT_SECONDS:
		await get_tree().create_timer(POLL_INTERVAL_SECONDS).timeout
		elapsed += POLL_INTERVAL_SECONDS

	if not _tx_blockhash_ok:
		tx.queue_free()
		_finish_transaction_op()
		return {"ok": false, "error": "blockhash_failed"}

	var tx_bytes: PackedByteArray = tx.serialize()

	plugin.call("signTransaction", tx_bytes)

	elapsed = 0.0
	var status: int = 0
	while status == 0 and elapsed < CONNECT_TIMEOUT_SECONDS:
		await get_tree().create_timer(POLL_INTERVAL_SECONDS).timeout
		elapsed += POLL_INTERVAL_SECONDS
		status = plugin.call("getSigningStatus")

	if status != 1:
		tx.queue_free()
		_finish_transaction_op()
		return {"ok": false, "error": "signing_failed_or_timeout"}

	var raw_response: PackedByteArray = plugin.call("getMessageSignature")
	plugin.call("clearStateFullReset")
	tx.queue_free()

	if raw_response.size() < 65:
		_finish_transaction_op()
		return {"ok": false, "error": "signed_response_too_small"}

	var signed_tx = Transaction.new_from_bytes(raw_response)
	add_child(signed_tx)
	signed_tx.url_override = rpc_url

	_tx_send_done = false
	_tx_send_result = null
	signed_tx.transaction_response_received.connect(_on_tx_send_response, CONNECT_ONE_SHOT)
	signed_tx.send()

	elapsed = 0.0
	while not _tx_send_done and elapsed < CONNECT_TIMEOUT_SECONDS:
		await get_tree().create_timer(POLL_INTERVAL_SECONDS).timeout
		elapsed += POLL_INTERVAL_SECONDS

	signed_tx.queue_free()
	_finish_transaction_op()

	if typeof(_tx_send_result) == TYPE_DICTIONARY and _tx_send_result.has("result"):
		return {"ok": true, "signature": String(_tx_send_result.result)}

	return {"ok": false, "error": "broadcast_failed_or_timeout", "raw": _tx_send_result}

func _finish_transaction_op() -> void:
	if OS.get_name() == "Android":
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
	_current_operation = ""

func _on_tx_blockhash_updated(result: Dictionary) -> void:
	_tx_blockhash_result = result
	_tx_blockhash_ok = result.has("result")
	_tx_blockhash_failed = not _tx_blockhash_ok

func _on_tx_blockhash_failed_handler(_result = null) -> void:
	_tx_blockhash_failed = true

func _on_tx_fully_signed() -> void:
	_tx_signed = true

func _on_tx_signing_failed(_error = null) -> void:
	_tx_sign_failed = true

func _on_tx_send_response(result: Variant) -> void:
	_tx_send_result = result
	_tx_send_done = true