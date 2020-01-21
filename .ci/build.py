#!/usr/bin/env python3

import argparse
import os
import platform
import sys
from pathlib import Path
from typing import List, Tuple

from ci_exec import CMakeParser, Provider, Styles, cd, fail, filter_file, log_stage, \
                    rm_rf, unified_diff, which

if sys.version_info < (3, 6):  # Uses: f-strings
    fail("Python 3.6 or later required to run this file.")


this_file_dir = Path(__file__).resolve().parent
"""Directory this file is in."""

project_root = this_file_dir.parent
"""Directory of the repository root."""


def log_sub_stage(stage: str):
    log_stage(stage, fill_char="-", style=Styles.Regular)


def install_dependencies(build_root: Path, configure_args: List[str],
                         build_args: List[str]):
    """Locally install Eigen, GLAD, and GLFW."""
    log_stage("Installing Third Party Dependencies Locally")
    cmake = which("cmake")
    git = which("git")

    # CI builds can test shared and static builds.  Download sources once.
    source_root = this_file_dir / "source"
    with cd(source_root, create=True):
        # Download Eigen dependency.
        eigen_src_dir = source_root / "eigen"
        if not eigen_src_dir.exists():
            log_sub_stage("Downloading Eigen")
            git("clone", "--depth", "1",
                "https://github.com/eigenteam/eigen-git-mirror.git", "eigen")

            # Comment out export(PACKAGE) calls to guarantee installed package
            # found (had some trouble on Windows without the patching ...).
            eigen_cml = eigen_src_dir / "CMakeLists.txt"
            original = filter_file(eigen_cml,
                                   r"export \(PACKAGE Eigen3\)",
                                   "# export (PACKAGE Eigen3)",
                                   line_based=True)
            print("Patched Eigen:")
            print(unified_diff(original, eigen_cml))

        # Download GLFW dependency.
        glfw_src_dir = source_root / "glfw"
        if not glfw_src_dir.exists():
            log_sub_stage("Downloading GLFW")
            git("clone", "--depth=1", "https://github.com/glfw/glfw.git")

        # Download GLAD dependency.
        glad_src_dir = source_root / "glad"
        if not glad_src_dir.exists():
            log_sub_stage("Downloading GLAD")
            git("clone", "--depth=1", "https://github.com/Dav1dde/glad.git")

    # Now that we have the source directories build them.
    # Install Eigen dependency.
    log_sub_stage("Installing Eigen")
    eigen_build_dir = build_root / "eigen"
    rm_rf(eigen_build_dir)
    with cd(eigen_build_dir, create=True):
        cmake(str(eigen_src_dir), *configure_args, "-DBUILD_TESTING=OFF")
        cmake("--build", ".", *build_args, "--target", "install")

    # Install GLFW dependency.
    log_sub_stage("Installing GLFW")
    glfw_build_dir = build_root / "glfw"
    rm_rf(glfw_build_dir)
    with cd(glfw_build_dir, create=True):
        glfw_configure_args = [
            "-DGLFW_BUILD_EXAMPLES=OFF",
            "-DGLFW_BUILD_TESTS=OFF",
            "-DGLFW_BUILD_DOCS=OFF",
            "-DGLFW_INSTALL=ON"
        ]
        # NOTE: https://github.com/glfw/glfw/issues/528
        # This breaks any consuming library wanting to properly support these.
        # See also:
        # https://github.com/glfw/glfw/blob/2c7ef5b480d7780455deed43aedc177b9fe3ac61/CMakeLists.txt#L84
        if platform.system() == "Windows":
            static = any("BUILD_SHARED_LIBS=OFF" in c for c in configure_args)
            glfw_configure_args.extend([
                f"-DUSE_MSVC_RUNTIME_LIBRARY_DLL={'OFF' if static else 'ON'}",
                f"-DCMAKE_C_FLAGS_RELEASE=\"{'/MT' if static else '/MD'}\"",
                f"-DCMAKE_C_FLAGS_MINSIZEREL=\"{'/MT' if static else '/MD'}\"",
                f"-DCMAKE_C_FLAGS_RELWITHDEBINFO=\"{'/MTd' if static else '/MDd'}\"",
                f"-DCMAKE_C_FLAGS_DEBUG=\"{'/MTd' if static else '/MDd'}\"",
            ])
        cmake(str(glfw_src_dir), *configure_args, *glfw_configure_args)
        cmake("--build", ".", *build_args, "--target", "install")

    # Install GLAD dependency.
    log_sub_stage("Installing GLAD")
    glad_build_dir = build_root / "glad"
    rm_rf(glad_build_dir)
    with cd(glad_build_dir, create=True):
        cmake(str(glad_src_dir), *configure_args,
              "-DGLAD_PROFILE=core", "-DGLAD_INSTALL=ON")
        cmake("--build", ".", *build_args, "--target", "install")


def build(build_root: Path, install: bool, configure_args: List[str],
          build_args: List[str]):
    """Build and potentially (locally) install NanoGUI."""
    log_stage("Building NanoGUI")
    cmake = which("cmake")

    nanogui_build_dir = build_root / "nanogui"
    rm_rf(nanogui_build_dir)
    with cd(nanogui_build_dir, create=True):
        cmake(str(project_root), *configure_args)
        cmake("--build", ".", *build_args)
        if install:
            cmake("--build", ".", *build_args, "--target", "install")


def test_package(build_root: Path, configure_args: List[str], build_args: List[str]):
    """Build NanoGUI test package.  Assumes prior build with --install."""
    log_stage("Test NanoGUI Packaging")
    cmake = which("cmake")

    test_package_source = project_root / "test_package"
    test_package_build_dir = build_root / "test_package"
    rm_rf(test_package_build_dir)
    with cd(test_package_build_dir, create=True):
        cmake(str(test_package_source), *configure_args)
        cmake("--build", ".", *build_args)


if __name__ == "__main__":
    # NanoGUI defaults BUILD_SHARED_LIBS to ON.  In order to help facilitate
    # building dependencies for the external packaging tests, --shared or
    # --static are required to be provided.  This enables the
    # install_dependencies stage to be consistent with build stage (assuming
    # the same argument of --shared / --static is provided).
    parser = CMakeParser(
        description="NanoGUI CI Build Helper", shared_or_static_required=True
    )
    parser.add_argument(
        "stage", type=str,
        choices=["install_dependencies", "build", "test_package"],
        help="Build stage to execute."
    )
    parser.add_argument(
        "--install", action="store_true",
        help=(
            "Install NanoGUI locally?  Only valid with `build` stage.  Intent "
            "is to use in preparation for `test_package` stage."
        )
    )
    # TODO: parent/child test
    # TODO: cmake_minimum_required(VERSION ${CMAKE_VERSION} FATAL_ERROR) in
    #       parent (???) to catch upcoming policy changes.

    args = parser.parse_args()
    configure_args = args.cmake_configure_args
    build_args = args.cmake_build_args

    # NOTE: on Travis build parallelism needs to be reduced, can run out of
    # memory when linking (especially with Ninja).
    if parser.is_single_config_generator(args.generator):
        if Provider.is_travis():
            build_args.extend(["-j", "2"])
        else:
            build_args.append("-j")

    # Perform verbose builds on CI so we can see what flags are being passed.
    # It seems CMake will do the right thing for ninja and MSVC generators too.
    configure_args.append("-DCMAKE_VERBOSE_MAKEFILE=ON")

    # Build roots split for shared vs static to enable same CI job to build both
    # shared and static versions.
    # .ci/shared/{build,install} or .ci/static/{build,install}
    base = this_file_dir / ("shared" if args.shared else "static")
    build_root = base / "build"
    install_root = base / "install"

    # Everybody gets installed to the same place.
    CMAKE_INSTALL_PREFIX = "-DCMAKE_INSTALL_PREFIX={0}".format(
        str(install_root)
    )

    # Avoid needing to set CMAKE_PREFIX_PATH in CI by searching for the install
    # directories and adding as a configure argument if found.  Eigen, GLFW, and
    # GLAD all install cmake config files to different locations on *nix.
    prefix_paths = []
    for p in Path("share"), Path("lib") / "cmake", Path("lib64") / "cmake":
        prefix = install_root / p
        if prefix.is_dir():
            prefix_paths.append(str(prefix))
    if prefix_paths:
        configure_args.append("-DCMAKE_PREFIX_PATH={prefixes}".format(
            prefixes=";".join(prefix_paths)
        ))

    if args.stage == "install_dependencies":
        configure_args.append(CMAKE_INSTALL_PREFIX)
        install_dependencies(build_root, configure_args, build_args)
    elif args.stage == "build":
        if args.install:
            configure_args.extend([
                CMAKE_INSTALL_PREFIX, "-DNANOGUI_INSTALL=ON"
            ])
        build(build_root, args.install, configure_args, build_args)
    elif args.stage == "test_package":
        test_package(build_root, configure_args, build_args)
