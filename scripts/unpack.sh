#!/usr/bin/env bash

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
CONFIG_DIR="${HOME}/.config/nvim/"
DEPS_DIR="${HOME}/.config/nvim-deps/"

if [ ! -d "${SCRIPT_DIR}/nvim-deps" ]; then
	echo "Missing nvim-deps directory" >&2
	exit 1
fi

if [ ! -d "${SCRIPT_DIR}/config" ]; then
	echo "Missing neovim config directory" >&2
	exit 1
fi

mkdir -p "${CONFIG_DIR}"
cp -r "${SCRIPT_DIR}/config/*" "${CONFIG_DIR}"

mkdir -p "${DEPS_DIR}"
cp -r "${SCRIPT_DIR}/nvim-deps/*" "${DEPS_DIR}"
