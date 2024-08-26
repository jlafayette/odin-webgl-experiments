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


def main(args: Args):
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
		subprocess.run(["go", "build", "-o", server_dst, "main.go"])
	
	wasm_dst = public_dst / "_main.wasm"
	if args.odin or not wasm_dst.exists():
		print("building wasm...")
		clean(wasm_dst)
		subprocess.run([
			"odin", "build",
			project_dst,
			f"-out:{wasm_dst}",
			"-target:js_wasm32",
			"-o:minimal",
		])
	
	runtime_js_dst = public_dst / "runtime.js"
	if not runtime_js_dst.is_file():
		copy_runtime_js(runtime_js_dst)

	os.chdir(public_dst)

	try:
		subprocess.run([server_dst.name], shell=True)
	except KeyboardInterrupt:
		print("Shutting down server")
		sys.exit(0)


def clean(p: Path):
	if p.is_file():
		p.unlink()
	elif p.is_dir():
		p.rmdir()


def copy_runtime_js(dst: Path):
	# <!-- Copy `vendor:wasm/js/runtime.js` into your web server -->
	r = subprocess.check_output(["odin", "root"])
	src = Path(r.decode()) / "vendor/wasm/js/runtime.js"
	shutil.copy(src, dst)


def args():
	args = sys.argv[1:]
	if len(args) == 0:
		print("select project to run")
		sys.exit(1)
	build_go = "-g" in args
	build_odin = "-o" in args
	return Args(args[0], build_go, build_odin)


main(args())
