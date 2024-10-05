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

	dst_public = root_dir / "public"
	for src_public in paths:
		filenames = ["index.html", "_main.wasm", "style.css"]
		files = [src_public / f for f in filenames]
		files.extend(src_public.glob("*.js"))
		print(src_public)
		dst_path = dst_public / src_public.parent.name
		dst_path.mkdir(exist_ok=True)
		for src in files:
			if src.is_file():
				dst = dst_path / src.name
				print("   ", src, "->", dst)
				build.clean(dst)
				shutil.copy(src, dst)

		# for filename in ["index.html", "_main.wasm", "style.css"]:

		# shutil.copy(
		# 	(src_public / "index.html"),
		# 	(dst_public / "index.html"),
		# )
		# shutil.copy(
		# 	(src_public / "_main.wasm"),
		# 	(dst_public / "index.html"),
		# )

	print("building server...")
	server_dst = dst_public / "main.exe"
	build.clean(server_dst)
	subprocess.run(["go", "build", "-o", server_dst, "main.go"])


if __name__ == "__main__":
	main()
