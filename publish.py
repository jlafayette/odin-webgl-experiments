import os
import shutil
import sys
import subprocess
from pathlib import Path
from typing import NamedTuple

import build


root_dir = Path(__file__).absolute().parent


class Args(NamedTuple):
	build_go: bool


def main(args: Args):
	paths = []
	projects = [
		"multi",
		"trails",
		"rectangle",
		"input",
		"camera",
	]
	for project in projects:
		build_args = build.Args(project=project, go=False, odin=True, optimized=False, run=False)
		paths.append(build.main(build_args))
	os.chdir(root_dir)

	dist = root_dir / "dist"
	dist.mkdir(exist_ok=True)

	for src_public in paths:
		filenames = ["index.html", "_main.wasm", "style.css"]
		files = [src_public / f for f in filenames]
		files.extend(src_public.glob("*.js"))
		print(src_public)
		dst_path = dist / src_public.parent.name
		build.clean(dst_path)
		dst_path.mkdir(exist_ok=False)
		for src in files:
			if src.is_file():
				dst = dst_path / src.name
				print("   ", src, "->", dst)
				build.clean(dst)
				shutil.copy(src, dst)

	if args.build_go:
		print("building dev server...", end="")
		server_dst = dist / "main.exe"
		build.clean(server_dst)
		subprocess.run(["go", "build", "-o", server_dst, "main.go"])
		print(" done")
		print(
			"To run dev server:\n"
			"\tcd dist\n"
			"\t.\\main.exe -no-watch -no-build\n"
		)


def args():
	args = sys.argv[1:]
	if "-g" in args or "--dev" in args:
		build_go = True
	else:
		build_go = False
	return Args(build_go)


if __name__ == "__main__":
	main(args())
