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


root_dir = Path(__file__).absolute().parent


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
	
	odin_js_dst = public_dst / "odin.js"
	clean(odin_js_dst)
	copy_odin_js(odin_js_dst)
	resize_js_dst = public_dst / "odin-resize.js"
	clean(resize_js_dst)
	shutil.copy(root_dir / "shared/resize/odin-resize.js", resize_js_dst)
	gamepad_js_dst = public_dst / "odin-gamepad.js"
	clean(gamepad_js_dst)
	shutil.copy(root_dir / "shared/gamepad/odin-gamepad.js", gamepad_js_dst)

	if args.run:
		os.chdir(public_dst)
		r = subprocess.check_output(["odin", "root"])
		odin_exe = Path(r.decode()) / "odin"
		try:
			subprocess.run([server_dst.name, odin_exe], shell=True, check=True)
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


def copy_odin_js(dst: Path):
	# <!-- Copy `vendor:wasm/js/runtime.js` into your web server -->
	r = subprocess.check_output(["odin", "root"])
	src = Path(r.decode()) / "core/sys/wasm/js/odin.js"
	shutil.copy(src, dst)


def args():
	args = sys.argv[1:]
	if len(args) == 0:
		print("select project to run")
		sys.exit(1)
	build_go = "-g" in args
	build_odin = "--odin" in args
	optimize = "-o" in args or "--optimize" in args
	return Args(args[0], build_go, build_odin, optimize, True)


if __name__ == "__main__":
	main(args())
