
function lookupCursor(u8) {
	const lookup = {
		0: "auto",
		1: "default",
		2: "none",
		3: "context-menu",
		4: "help",
		5: "pointer",
		6: "progress",
		7: "wait",
		8: "cell",
		9: "crosshair",
		10: "text",
		11: "vertical-text",
		12: "alias",
		13: "copy",
		14: "move",
		15: "no-drop",
		16: "not-allowed",
		17: "grab",
		18: "grabbing",
		19: "e-resize",
		20: "n-resize",
		21: "ne-resize",
		22: "nw-resize",
		23: "s-resize",
		24: "se-resize",
		25: "sw-resize",
		26: "w-resize",
		27: "ew-resize",
		28: "ns-resize",
		29: "nesw-resize",
		30: "nwse-resize",
		31: "col-resize",
		32: "row-resize",
		33: "all-scroll",
		34: "zoom-in",
		35: "zoom-out",
	}
	let result = lookup[u8];
	if (!result) {
		result = "default";
	}
	return result;
}

function setupImports(wasmMemoryInterface, consoleElement, memory) {
	const env = {};
	if (memory) {
		env.memory = memory;
	}
	return {
		env,
		"odin_cursor": {
			setCursor: (u8) => {
				console.log("setCursor got arg:", u8);
				// const value = wasmMemoryInterface.loadString(ptr, len);
				const value = lookupCursor(u8);
				console.log("setCursor lookup value:", value);
				const canvas = document.getElementById("canvas-1");
				canvas.style.cursor = value;
			},
		},
	};
}
window.odinCursor = {
	setupImports: setupImports,
}
