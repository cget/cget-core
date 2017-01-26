# cget - The missing package manager for cmake

## Background

CMake does a wonderful job of abstracting C and C++ build systems, bringing true cross-platform compatibility to C projects with minimal configuration.

Unfortunately, while cmake takes care of the build portion of package management, it does not address package resolution. Developers still have to track down either a source or binary distribution for each of their projects, download or clone them, and place them in the correct locations for cmake to find.

cget brings C/C++ closer to parity with other language's tools (e.g. npm, pip, maven, gradle) by bringing cross-platform module resolution to cmake. cget does this in the way which is most native to each system:

* If source is available, cget can grab it from git / hg / svn / tarball and build it using many types of standard build tools; although it obviously works better when the target build system is cmake. 
* On platforms with package managers, a package can also be configured to be resolved from that package manager. This side-steps certain packages on windows which are difficult to build, as well as taking much less time.
* cget works seemlessly with cmake, being written entirely as a cmake module, it requires no 3rd party run time or separate language

cget performs these operations transitively, which means a single command should be all you need to build your entire project and all of it's dependencies.

## Can't you just use find_package / find_library / etc?

Internally cget uses all of this functionality from cmake. However, those commands don't help you if you haven't installed the requested package. Loosely, cget does the following

* Find the package and download it
* Build the package
* Calls find_package 

## Registry

cget can transitively resolve projects with working cmake builds, but naturally not all projects support cmake or support all platforms which cmake supports. If a package cannot be found, cget will check with the main [cget repository](https://github.com/cget) and use those helper files instead. A dozen common modules are already supported (OpenSSL, SDL2, glew, etc), and contributions are welcome! cget believes in the open-source, and strongly embraces continual improvement and community.

Most of those commands are simple things like installing a non-standard 'Find.cmake' file, or setting compilation options which are known to work. They also will include callouts to all other required libraries so there are no unresolved dependencies. 

## How it works

cget is implemented as a cmake script that you are encouraged to add as a submodule to your git-enabled project under '.cget'. Once added, you can add one line to include cget:

```
include("${CMAKE_SOURCE_DIR}/.cget/core.cmake" REQUIRED)
```

Then you can add dependencies to your project simply by declaring them like in the following examples:

```
CGET_HAS_DEPENDENCY(glew NUGET_PACKAGE glew.${CGET_MSVC_RUNTIME} GITHUB nigels-com/glew VERSION glew-1.11.0)
CGET_HAS_DEPENDENCY(SDL2 REGISTRY VERSION master)
CGET_HAS_DEPENDENCY(GLUT NUGET_PACKAGE nupengl.core GITHUB dcnieho/FreeGLUT VERSION FG_3_0_0)
```
By convention, all these declarations are kept in a 'package.cmake' file which you include in your main CMakeLists.txt file. 

Dependencies can come either from a variety of sources -- git, nuget, git, hg, svn or a URL -- and cget will attempt to resolve them in that order. If that project also uses cget (or is in the cget registry) it will attempt to resolve packages transitively.

Downloaded dependencies are cached in the `.cget-bin/` folder underneath your project's root, and subsequent builds will execute quickly as long as your dependancies remain in cache. All output `lib`, `bin`, and `include` files are stored in the `.cget-bin/install_root/` folder for a single place to look.

In the near future, you will also be able to configure a particular folder to act as the cget-bin for the current user; which saves time if you use multiple repos.

## Command Reference

* CGET_HAS_DEPENDENCY(name [options]) - Download, build, and ultimately call find_package with the given name. 

Options can be specified in any order:

### Flag Options

* NO_FIND_PACKAGE - If present, performs every step but find_package. Can be useful if there is additional commands that need to be ran before find_package, a find cmake file doesn't exist, or you want to call find_package with custom options. 
* REGISTRY - If present, the package is resolved from the cget registry with the name given to the dependency
* NOSUBMODULES - By default, git repos will download sub modules. This disables that behavior. 

### Single argument options

* GITHUB [username/reponame] - Resolve the package at the given github repo
* GIT [git-url] - Resolve the package at the given git repo
* HG [hg-url] - Resolve the package at the given mercurial repo (WIP)
* SVN [svn-url] - Resolve the package at the given SVN url (WIP)
* NUGET_PACKAGE [pkg-name] - Resolve the package with nuget. Note that this works only on windows, if you want cross platform support you are advised to also include another resolution method. 
* VERSION [version] - Resolve this specific version. Can be 
* FINDNAME [altname] - Use this name when calling find_package
* COMMIT_ID [hash] - Get this specific commit 
* REGISTRY_VERSION - For registry packages, use this version of the registry repo

### Multi-value arguments

* OPTIONS - Calls build tool with these options. 
* FIND_OPTIONS - Additional options to pass into find_package

## For Repo Maintainers

Cget was written explicitly with out of the box functionality in mind -- it uses find_package internally, and attempts to leverage all of CMakes internal package management. 

If you have a library or tool that you want cget to be able to use, the easiest way to do that is to just follow all the best practices for cmake and provide a cmake installation target which correctly installs all assets, as well as provides a module config file. 

## Contributing

If you'd like to contribute, please fork this repository and send a PR with your changes. 

If you find you have to make a glue layer for a package you want to use, we also would love to move it into the registry so that other people can find and use it too. 
