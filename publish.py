import os
import shutil
import subprocess
from pathlib import Path

import build


root_dir = Path(__file__).absolute().parent


def main():
	paths = []
	projects = [
		"multi",
		"trails",
	]
	for project in projects:
		args = build.Args(project=project, go=False, odin=True, optimized=True, run=False)
		paths.append(build.main(args))
	os.chdir(root_dir)

	dist = root_dir / "dist"
	build.clean(dist)
	dist.mkdir(exist_ok=False)
	shutil.copy(root_dir / "public/index.html", dist / "index.html")

	for src_public in paths:
		filenames = ["index.html", "_main.wasm", "style.css"]
		files = [src_public / f for f in filenames]
		files.extend(src_public.glob("*.js"))
		print(src_public)
		dst_path = dist / src_public.parent.name
		dst_path.mkdir(exist_ok=False)
		for src in files:
			if src.is_file():
				dst = dst_path / src.name
				print("   ", src, "->", dst)
				build.clean(dst)
				shutil.copy(src, dst)

	print("building dev server...", end="")
	server_dst = dist / "main.exe"
	build.clean(server_dst)
	subprocess.run(["go", "build", "-o", server_dst, "main.go"])
	print(" done")
	print(
		"To run dev server:\n"
		"\tcd dist\n"
		"\t.\main.exe -no-watch -no-build\n"
	)


if __name__ == "__main__":
	main()
