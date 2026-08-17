// Browser terminal client - the playtest path and hardware-failure
// fallback for the 12 ESP32-S3 ship terminals (CLAUDE.md's Runtime
// topology). If a terminal dies mid-game, a player picks up this page
// on any browser or phone and keeps playing.
//
// Messages are flat JSON with a "type" field (see net/message.gd).
// This sends only the two message types net/message_router.gd
// currently handles, and never validates or second-guesses what the
// player types - see CLAUDE.md constraint 1: coordinates are never
// checked against real star system data, here or on the server. No
// CDN or external service - this has to work with no internet access.

// Mirrors ui/main.gd's WS_LISTEN_PORT - keep these two in sync. The
// server listens for WebSocket upgrades on a separate port from the
// one this page was served from (see net/server.gd's comment on why
// one port can't do both).
const WS_PORT = 8081;

// Mirrors core/ship_registry.gd - keep these two lists in sync.
const SHIPS = [
	["aegis", "AEGIS"],
	["dione", "Dione"],
	["icebreaker", "Icebreaker"],
	["shepherd", "Shepherd"],
	["quellon", "Quellon"],
	["refinery_124", "Refinery 124"],
];

const statusEl = document.getElementById("status");
const shipSelect = document.getElementById("ship");
const coordinatesInput = document.getElementById("coordinates");
const sendCoordinatesButton = document.getElementById("send-coordinates");
const driveToggleButton = document.getElementById("drive-toggle");

for (const [id, name] of SHIPS) {
	const option = document.createElement("option");
	option.value = id;
	option.textContent = name;
	shipSelect.appendChild(option);
}

let socket = null;

function setStatus(text, className) {
	statusEl.textContent = text;
	statusEl.className = `status ${className}`;
}

function send(type, fields) {
	if (socket && socket.readyState === WebSocket.OPEN) {
		socket.send(JSON.stringify({ type, ...fields }));
	}
}

function connect() {
	socket = new WebSocket(`ws://${window.location.hostname}:${WS_PORT}/`);

	socket.addEventListener("open", () => setStatus("connected", "status-connected"));
	socket.addEventListener("close", () => {
		setStatus("disconnected - retrying", "status-disconnected");
		setTimeout(connect, 2000);
	});
	socket.addEventListener("error", () => socket.close());
}

sendCoordinatesButton.addEventListener("click", () => {
	send("set_jump_coordinates", {
		ship_id: shipSelect.value,
		coordinates: coordinatesInput.value,
	});
});

driveToggleButton.addEventListener("click", () => {
	const charged = driveToggleButton.dataset.charged !== "true";
	driveToggleButton.dataset.charged = String(charged);
	driveToggleButton.textContent = charged ? "Charged" : "Uncharged";
	send("set_drive_charged", { ship_id: shipSelect.value, charged });
});

connect();
