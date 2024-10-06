import subprocess
import shutil
import sys
import os
from pathlib import Path
from typing import NamedTuple


class Args(NamedTuple):
	project: str
	go: bool
	odin: bool
	optimized: bool
	run: bool


def main(args: Args) -> Path:
	print(args)
	project_dst = Path(args.project)
	public_dst = project_dst / "public"
	if not public_dst.is_dir():
		print(f"No public folder found for project: {project_dst}")
		sys.exit(1)
	
	server_dst = public_dst / "main.exe"
	if args.go or not server_dst.exists():
		print("building server...")
		clean(server_dst)
		subprocess.run(["go", "build", "-o", server_dst, "main.go"], check=True)
	
	wasm_dst = public_dst / "_main.wasm"
	if args.odin or not wasm_dst.exists():
		print("building wasm...")
		clean(wasm_dst)
		build_args = [
			"odin", "build", project_dst, f"-out:{wasm_dst}", "-target:js_wasm32"
		]
		if args.optimized:
			build_args.extend(["-o:aggressive", "-disable-assert", "-no-bounds-check"])
		else:
			build_args.extend(["-o:minimal"])
		subprocess.run(build_args, check=True)
	
	runtime2 = "runtime-2.js" in (public_dst / "index.html").read_text()
	if runtime2:
		gamepad_dst = public_dst / "gamepad-copy.js"
		if not gamepad_dst.is_file():
			copy_gamepad_js(gamepad_dst)
		runtime_js_dst = public_dst / "runtime-2.js"
		if not runtime_js_dst.is_file():
			copy_runtime2_js(runtime_js_dst)
	else:
		runtime_js_dst = public_dst / "runtime.js"
		if not runtime_js_dst.is_file():
			copy_runtime_js(runtime_js_dst)

	if args.run:
		os.chdir(public_dst)
		try:
			subprocess.run([server_dst.name], shell=True, check=True)
		except KeyboardInterrupt:
			print("Shutting down server")
			sys.exit(0)

	return public_dst


def clean(p: Path):
	if p.is_file():
		p.unlink()
	elif p.is_dir():
		shutil.rmtree(p)


def copy_gamepad_js(dst: Path):
	src = Path("input/public/gamepad.js")
	shutil.copy(src, dst)


def copy_runtime_js(dst: Path):
	# <!-- Copy `vendor:wasm/js/runtime.js` into your web server -->
	r = subprocess.check_output(["odin", "root"])
	src = Path(r.decode()) / "vendor/wasm/js/runtime.js"
	shutil.copy(src, dst)


def copy_runtime2_js(dst: Path):
	"""Load gamepad js bindings and patch them into runtime.js file."""
	r = subprocess.check_output(["odin", "root"])
	src = Path(r.decode()) / "vendor/wasm/js/runtime.js"
	
	src_lines = src.read_text().splitlines()

	dst_lines = []
	for line in src_lines:
		dst_lines.append(line)
		if line.strip() == '"use strict";':
			dst_lines.append("import * as gamepad from './gamepad-copy.js';")
		elif line.strip() == 'exports._start();':
			dst_lines.append("gamepad.setup(wasmMemoryInterface, exports);")
		elif line.strip() == 'const step = (currTimeStamp) => {':
			dst_lines.append("gamepad.step(wasmMemoryInterface, exports);")
	dst.write_text("\n".join(dst_lines))


def args():
	args = sys.argv[1:]
	if len(args) == 0:
		print("select project to run")
		sys.exit(1)
	build_go = "-g" in args
	build_odin = "-o" in args
	return Args(args[0], build_go, build_odin, False, True)


if __name__ == "__main__":
	main(args())
