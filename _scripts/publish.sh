#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

index_url=$(git remote get-url origin)
index_root="$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")"

rev=""
manifest_path=""
package=""

usage() {
	cat <<EOF
Usage: $(basename "$0") --repository-url URL [--rev REV] [--manifest-path PATH] [--package NAME]

Required arguments:
  --repository-url URL     Git repository URL of the target crate (e.g., https://github.com/user/repo.git)

Optional arguments:
  --rev REV                Git revision to check out (commit, branch, or tag)
  --manifest-path PATH     Relative path to the crate's Cargo.toml (e.g., crates/my_crate)
  --package NAME           Name of the package within the workspace to target
  -h, --help               Show this help message and exit
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	--repository-url)
		repository_url="$2"
		shift 2
		;;
	--rev)
		rev="$2"
		shift 2
		;;
	--manifest-path)
		manifest_path="$2"
		shift 2
		;;
	--package)
		package="$2"
		shift 2
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		echo "Error: Unknown argument: $1" >&2
		usage
		exit 1
		;;
	esac
done

if [[ -z "${repository_url:-}" ]]; then
	echo "Error: --repository-url is required" >&2
	usage
	exit 1
fi

clone_dir="$(mktemp -d)"
crate_out_dir="$(mktemp -d)"

trap 'rm -rf "$clone_dir" "$crate_out_dir"' EXIT

echo "Cloning: $repository_url"
[[ -n "$rev" ]] && echo "Using revision: $rev"
[[ -n "$manifest_path" ]] && echo "Workspace path: $manifest_path"
[[ -n "$package" ]] && echo "Target package: $package"

if [[ -n "$rev" ]]; then
	git clone --no-checkout --depth 1 "$repository_url" "$clone_dir"
	git -C "$clone_dir" fetch --depth 1 origin "$rev"
	git -C "$clone_dir" checkout FETCH_HEAD
else
	git clone --depth 1 "$repository_url" "$clone_dir"
fi

cargo_opts=()
pkg_opts=()

if [[ -n "${manifest_path:-}" ]]; then
	manifest_path="${clone_dir%/}/${manifest_path}"
else
	manifest_path="${clone_dir%/}/Cargo.toml"
fi

cargo_opts+=(--manifest-path "$manifest_path")

if [[ -n "${package:-}" ]]; then
	pkg_opts+=(--package "$package")
fi

if [[ -n "${package:-}" ]]; then
	read -r name version < <(cargo metadata --format-version 1 --no-deps "${cargo_opts[@]}" |
		jq -r --arg package "$package" '.packages[] | select(.name == $package) | "\(.name)\t\(.version)"')
else
	read -r name version < <(cargo metadata --format-version 1 --no-deps "${cargo_opts[@]}" |
		jq -r '.packages[0] | "\(.name)\t\(.version)"')
fi

(git fetch origin crates --depth=1 && git update-ref refs/heads/crates origin/crates) || git branch crates

cargo package --target-dir "$crate_out_dir" "${cargo_opts[@]}" "${pkg_opts[@]}"
crate_path="${crate_out_dir%/}/package/${name}-${version}.crate"
cargo index add --index "$index_root" --index-url "$index_url" --crate "$crate_path"
commit_msg=$(git log -1 --pretty=%B)

git checkout crates
crate_dst="${index_root%/}/crates/${name}/${version}"
mkdir -p "$crate_dst"
cp "$crate_path" "${crate_dst%/}/download"
git add "$crate_dst"
git commit -m "$commit_msg"
