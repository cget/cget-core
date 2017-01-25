# cget - The missing package manager for cmake

## Background

cmake does a wonderful job of abstracting C and C++ build systems, bringing true cross-platform compatibility to C projects with minimal configuration.

Unfortunately, while cmake takes care of the build portion of package management, it does not address package resolution. Developers still have to track down either a source or binary distribution for each of their projects, download or clone them, and place them in the correct locations for cmake to find.

cget brings C/C++ closer to parity with other language's tools (e.g. npm, pip, maven, gradle) by bringing cross-platform module resolution to cmake. cget does this in the way which is most native to each system:

* on Windows, cget will attempt to resolve packages with nuget if possible
* When other forms of resolution fail, cget will clone repositories from github, using binaries if present, or building from source when needed
* cget works seemlessly with cmake, being written entirely as a cmake module, it requires no 3rd party run time or separate language

cget performs these operations transitively, which means a single command should be all you need to build your entire project and all of it's dependencies.

## repositories

cget can transitively resolve projects with working cmake builds, but naturally not all projects support cmake or support all platforms which cmake supports. If a package cannot be found, cget will check with the main [cget repository](https://github.com/cget) and use those build files instead. A dozen common modules are already supported (OpenSSL, SDL2, glew, etc), and contributions are welcome! cget believes in the open-source, and strongly embraces continual improvement and community.

## How it works

cget is implemented as a cmake script that you can add as a submodule to your git-enabled project. Once added, you can add one line to include cget:

```
include("${CMAKE_SOURCE_DIR}/.cget/core.cmake" REQUIRED)
```

Then you can add dependencies to your project simply by declaring them like in the following examples:

```
CGET_HAS_DEPENDENCY(glew NUGET_PACKAGE glew.${CGET_MSVC_RUNTIME} GITHUB nigels-com/glew VERSION glew-1.11.0)
CGET_HAS_DEPENDENCY(SDL2 REGISTRY VERSION master)
CGET_HAS_DEPENDENCY(GLUT NUGET_PACKAGE nupengl.core GITHUB dcnieho/FreeGLUT VERSION FG_3_0_0)
```

Dependencies can come either from nuget, or from github, and cget will attempt to resolve them in that order.

If you have git installed on your path, it will clone the repository then attempt to run the cmake build. If that project also uses cget (or is in the cget registry) it will attempt to resolve packages transitively.

Downloaded dependencies are cached in the `.cget-bin/` folder underneath your project's root, and subsequent builds will execute quickly as long as your dependancies remain in cache. All output `lib`, `bin`, and `include` files are stored in the `.cget-bin/installed/` folder for a single place to look.

## Contributing

If you'd like to contribute, please fork this repository and send a PR with your changes. 
