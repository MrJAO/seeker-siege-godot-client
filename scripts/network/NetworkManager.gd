extends Node

var base_url: String = "https://api.seekersiege.xyz"

var access_token: String = ""
var refresh_token: String = ""
var player_id: int = -1

var _refreshing: bool = false

signal login_success(player_id: int)
signal login_failed(status: int, data: Variant)
signal session_expired

const _AUTH_ROUTES := ["/auth/nonce", "/auth/verify", "/auth/debug-login", "/auth/refresh"]

func debug_login() -> void:
	var result: Dictionary = await request_json(HTTPClient.METHOD_POST, "/auth/debug-login", {})

	if result.ok:
		access_token = result.data.get("accessToken", "")
		refresh_token = result.data.get("refreshToken", "")
		player_id = int(result.data.get("playerId", -1))
		print("[NetworkManager] debug login ok, playerId=", player_id, " wallet=", result.data.get("wallet", ""))
		login_success.emit(player_id)
	else:
		print("[NetworkManager] debug login failed: ", result.status, " ", result.data)
		login_failed.emit(result.status, result.data)

# MWA login
func wallet_login() -> void:
	var connected: bool = await WalletManager.connect_wallet()
	if not connected:
		login_failed.emit(0, {"error": "wallet_connect_failed"})
		return

	var wallet: String = WalletManager.wallet_address

	var nonce_result: Dictionary = await request_json(
		HTTPClient.METHOD_POST, "/auth/nonce", {"wallet": wallet}
	)
	if not nonce_result.ok:
		login_failed.emit(nonce_result.status, nonce_result.data)
		return

	var message: String = nonce_result.data.get("message", "")
	var signature_bytes: PackedByteArray = await WalletManager.sign_message(message)
	if signature_bytes.is_empty():
		login_failed.emit(0, {"error": "signing_failed_or_cancelled"})
		return

	var signature_b64: String = Marshalls.raw_to_base64(signature_bytes)

	var verify_result: Dictionary = await request_json(
		HTTPClient.METHOD_POST, "/auth/verify", {"wallet": wallet, "signature": signature_b64}
	)

	if verify_result.ok:
		access_token = verify_result.data.get("accessToken", "")
		refresh_token = verify_result.data.get("refreshToken", "")
		player_id = int(verify_result.data.get("playerId", -1))
		print("[NetworkManager] wallet login ok, playerId=", player_id, " wallet=", wallet)
		login_success.emit(player_id)
	else:
		print("[NetworkManager] wallet login failed: ", verify_result.status, " ", verify_result.data)
		login_failed.emit(verify_result.status, verify_result.data)

func request_json(method: int, path: String, body: Dictionary) -> Dictionary:
	var result: Dictionary = await _send_request(method, path, body)

	if result.status == 401 and not _AUTH_ROUTES.has(path):
		var refreshed: bool = await _try_refresh()
		if refreshed:
			result = await _send_request(method, path, body)
		else:
			session_expired.emit()

	return result

func _try_refresh() -> bool:
	if refresh_token == "":
		return false
	if _refreshing:
		return false

	_refreshing = true
	var result: Dictionary = await _send_request(
		HTTPClient.METHOD_POST, "/auth/refresh", {"refreshToken": refresh_token}
	)
	_refreshing = false

	if result.ok:
		access_token = result.data.get("accessToken", "")
		refresh_token = result.data.get("refreshToken", "")
		player_id = int(result.data.get("playerId", player_id))
		print("[NetworkManager] access token refreshed")
		return true
	else:
		print("[NetworkManager] refresh failed: ", result.status, " ", result.data)
		return false

func _send_request(method: int, path: String, body: Dictionary) -> Dictionary:
	var http := HTTPRequest.new()
	http.use_threads = true
	add_child(http)

	var headers := ["Content-Type: application/json"]
	if access_token != "":
		headers.append("Authorization: Bearer " + access_token)
	var json_body := JSON.stringify(body)
	var err := http.request(base_url + path, headers, method, json_body)

	if err != OK:
		http.queue_free()
		return {"ok": false, "status": 0, "data": {"error": "request_failed_to_start"}}

	var response: Array = await http.request_completed
	http.queue_free()

	var response_code: int = response[1]
	var body_bytes: PackedByteArray = response[3]
	var text := body_bytes.get_string_from_utf8()
	var parsed = JSON.parse_string(text)

	if parsed == null:
		parsed = {}

	return {
		"ok": response_code >= 200 and response_code < 300,
		"status": response_code,
		"data": parsed,
	}
