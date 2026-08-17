// Player secret-info page - reached by a per-player QR code/link the
// host generates in the host console (ui/host/host_console.gd). Shows
// exactly what open_questions_answered.md §4.5 says a phone page
// carries: this player's own suspicion number and any clues the
// facilitator has sent. Nothing else - loyalty itself stays on paper
// (CLAUDE.md constraint 4), and this page never learns any other
// player's data; the server only ever sends this connection its own
// player_state (see ui/main.gd's per-player channel).

// Mirrors ui/main.gd's WS_LISTEN_PORT - keep these two in sync.
const WS_PORT = 8081;

const statusEl = document.getElementById("status");
const noPlayerEl = document.getElementById("no-player");
const playerViewEl = document.getElementById("player-view");
const suspicionValueEl = document.getElementById("suspicion-value");
const clueListEl = document.getElementById("clue-list");
const noCluesEl = document.getElementById("no-clues");

const playerId = new URLSearchParams(window.location.search).get("id");

function setStatus(text, className) {
	statusEl.textContent = text;
	statusEl.className = `status ${className}`;
}

function render(state) {
	suspicionValueEl.textContent = String(state.suspicion ?? 0);

	const clues = state.clues ?? [];
	clueListEl.innerHTML = "";
	noCluesEl.classList.toggle("hidden", clues.length > 0);
	// Newest first, matching the TV display's announcement feed.
	for (const clue of [...clues].reverse()) {
		const item = document.createElement("li");
		item.textContent = `Turn ${clue.turn_number}: ${clue.text}`;
		clueListEl.appendChild(item);
	}
}

if (!playerId) {
	noPlayerEl.classList.remove("hidden");
} else {
	playerViewEl.classList.remove("hidden");

	let socket = null;

	function connect() {
		socket = new WebSocket(`ws://${window.location.hostname}:${WS_PORT}/`);

		socket.addEventListener("open", () => {
			setStatus("connected", "status-connected");
			socket.send(JSON.stringify({ type: "identify_player", player_id: playerId }));
		});
		socket.addEventListener("close", () => {
			setStatus("disconnected - retrying", "status-disconnected");
			setTimeout(connect, 2000);
		});
		socket.addEventListener("error", () => socket.close());
		socket.addEventListener("message", (event) => {
			const message = JSON.parse(event.data);
			if (message.type === "player_state") {
				render(message.state);
			}
		});
	}

	connect();
}
