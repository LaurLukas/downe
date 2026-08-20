// Browser terminal client - the playtest path and hardware-failure
// fallback for the 12 ESP32-S3 ship terminals (CLAUDE.md's Runtime
// topology). If a terminal dies mid-game, a player picks up this page
// on any browser or phone and keeps playing.
//
// Messages are flat JSON with a "type" field (see net/message.gd).
// This sends set_jump_coordinates/set_drive_charged/roll_request, and
// never validates or second-guesses what the player types for the
// first two - see CLAUDE.md constraint 1: coordinates are never
// checked against real star system data, here or on the server. No
// CDN or external service - this has to work with no internet access.
//
// Dice rendering below follows docs/dice_engine_spec.md §8 exactly:
// the client already knows the true roll result the moment roll_result
// arrives (constraint 1 there too - all randomness is server-side, this
// never predicts or computes an outcome), and only tumbles through
// random-looking faces as a purely cosmetic animation before settling
// on the real ones.

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
	socket.addEventListener("message", (event) => {
		let message;
		try {
			message = JSON.parse(event.data);
		} catch {
			return;
		}
		if (message.type === "roll_result") {
			onRollResult(message);
		}
	});
}

// --- Dice (docs/dice_engine_spec.md) ----------------------------------

const rollRiotButton = document.getElementById("roll-riot");
const diceRow = document.getElementById("dice-row");
const diceArithmetic = document.getElementById("dice-arithmetic");
const overrideBadge = document.getElementById("dice-override-badge");
const rollLogEl = document.getElementById("roll-log");

rollRiotButton.addEventListener("click", () => {
	send("roll_request", { ship: shipSelect.value, reason: "maintenance_riot" });
});

// Every roll_result this terminal ever receives (any ship - the server
// broadcasts to everyone, same as the "state" message). Kept so
// switching ships in the picker re-filters instantly without asking the
// server for anything.
let allRolls = [];

function onRollResult(message) {
	allRolls.push(message);
	if (allRolls.length > 200) {
		allRolls.shift();
	}
	renderRollLog();
	if (message.ship === shipSelect.value) {
		animateAndSettle(message);
	}
}

shipSelect.addEventListener("change", () => {
	diceRow.innerHTML = "";
	diceArithmetic.textContent = "";
	overrideBadge.hidden = true;
	renderRollLog();
});

// Spec §8's roll log: "that ship's last ~20 rolls: sequence number,
// reason, faces, outcome" - the artefact a suspicious player is pointed
// at when someone accuses the software of cheating.
function renderRollLog() {
	const shipId = shipSelect.value;
	const relevant = allRolls.filter((r) => r.ship === shipId).slice(-20);
	rollLogEl.innerHTML = "";
	for (const r of relevant) {
		const li = document.createElement("li");
		const faces = Array.isArray(r.faces) ? r.faces.join(", ") : "";
		li.textContent = `#${r.id} ${r.reason}: [${faces}] -> ${r.text}${r.over ? " (overridden)" : ""}`;
		if (r.over) {
			li.classList.add("roll-overridden");
		}
		rollLogEl.appendChild(li);
	}
}

// Standard 7-pip d6 layout, per-face subset - spec §8: "inline SVG...
// about thirty lines of JS, no dependencies." Dice stay white with dark
// pips regardless of ship colour, always - never render a red die (see
// style.css's --warn comment; red belongs exclusively to the Wolves).
const PIP_LAYOUT = {
	1: [[50, 50]],
	2: [[27, 27], [73, 73]],
	3: [[27, 27], [50, 50], [73, 73]],
	4: [[27, 27], [73, 27], [27, 73], [73, 73]],
	5: [[27, 27], [73, 27], [50, 50], [27, 73], [73, 73]],
	6: [[27, 22], [73, 22], [27, 50], [73, 50], [27, 78], [73, 78]],
};

function dieFaceSvg(value) {
	const pips = (PIP_LAYOUT[value] || [])
		.map(([x, y]) => `<circle cx="${x}" cy="${y}" r="8" fill="#1a1a1a"/>`)
		.join("");
	return `<svg class="die" viewBox="0 0 100 100" width="44" height="44" role="img" aria-label="die showing ${value}">
		<rect x="4" y="4" width="92" height="92" rx="16" fill="#fff" stroke="#1a1a1a" stroke-width="4"/>
		${pips}
	</svg>`;
}

function renderDice(faces) {
	diceRow.innerHTML = faces.map(dieFaceSvg).join("");
}

const REDUCED_MOTION = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
const TUMBLE_MS = 700;
const TUMBLE_FRAME_MS = 1000 / 12;

// "The client already knows the true result before the animation
// starts. It animates toward a known answer." (spec §8) - message is
// already the real, server-computed result; the loop below only swaps
// in random-looking faces as a cosmetic tumble before settling on it.
function animateAndSettle(message) {
	const faces = Array.isArray(message.faces) ? message.faces : [];
	overrideBadge.hidden = true;

	if (REDUCED_MOTION || faces.length === 0) {
		settle(message, faces);
		return;
	}

	const start = performance.now();
	function tick(now) {
		if (now - start >= TUMBLE_MS) {
			settle(message, faces);
			return;
		}
		renderDice(faces.map(() => 1 + Math.floor(Math.random() * 6)));
		setTimeout(() => requestAnimationFrame(tick), TUMBLE_FRAME_MS);
	}
	requestAnimationFrame(tick);
}

// mod is reason-specific flavor text (spec's own example: "+9 rations")
// - only maintenance_unrest names its modifier that; anything else
// falls back to a generic "mod" label rather than guessing new flavor
// text for a reason key this terminal doesn't know about yet.
const MOD_LABELS = { maintenance_unrest: "rations" };

function settle(message, faces) {
	renderDice(faces);

	const parts = [];
	if (faces.length > 1) {
		parts.push(`${faces.join(" + ")} = ${faces.reduce((a, b) => a + b, 0)}`);
	}
	if (typeof message.mod === "number") {
		parts.push(`+${message.mod} ${MOD_LABELS[message.reason] || "mod"}`);
	}
	if (typeof message.total === "number") {
		parts.push(`= ${message.total}`);
	}
	if (typeof message.target === "number") {
		parts.push(`target ${message.target}+`);
	}
	if (message.text) {
		parts.push(message.text);
	}
	diceArithmetic.textContent = parts.join("   ");

	// Small, unmissable, not apologetic (spec §8) - a separate badge
	// rather than folding "(overridden)" quietly into the sentence above.
	overrideBadge.hidden = !message.over;
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
