#import "../../shared/blog.typ": blog-post, sidenote, theorem, definition, lemma, corollary
#show: blog-post.with(
  title: "Visual Studio Code for C++ development on MacOS",
  date: "2018-12-18",
  tags: ("Visual Studio Code", "开发环境", "闲话编程"),
  lang: "en",
)

I've tried lot's of c++ IDEs on MacOS X, but none of them is as powerful
as VS Studio on Windows. It's always hard for me to choose an IDE before
I want to write some code, as it's called the #emph[Selection phobia].
Generally we have the following choose:

- Vim/Emacs (I'm familiar with VIM but it's still not an easy way, for
  me)
- CodeBlocks (not good maintained on MacOS)
- CodeLite (it's a good choose!)
- XCode (I just don't like it, #strong[Heavy] and ugly, can't get used
  to it)
- QT Creator (it's useful especially when developing Qt projects)
- Eclipse CDT
- NetBeans
- CLion (maybe the best c++ IDE on MaxOS, unfortunately does not have a
  free version)
- Textmate

Recently I tried Visual Studio Code, it's really a good choose for those
who want to write some c++ code in a lightweight IDE.

= Setup Visual Studio Code for C++ development
<setup-visual-studio-code-for-c-development>
First we have to install
#link("https://code.visualstudio.com/")[Visual Studio Code], and a few
extensions:

- C/C++
- Easy C++ projects

After installed those extensions, reload the editor to activate them.
Now we can create a project:

- Choose File \> Open folder to open a work directory
- Press F1 and type "c++", then select "Create new C++ project" command.

After the above steps a new project with Makefile is generated.

= Common usage
<common-usage>
To debug or run the project, just click the button on the bottom status
bar, it's easy:

#figure(image("images/vscode_debugging.png", alt: "visual code studio snapshot"),
  caption: [
    visual code studio snapshot
  ]
)

to run other commands, you could just press F1 and guess, for example,
to format the code, just search "format" and then you got a choice.

= Update: How to setup eclipse CDT in MacOX
<update-how-to-setup-eclipse-cdt-in-macox>
Recently I tried to use eclipse-cdt with cmake build system, there are a
few tips:

- Need to install `cmake` and `ninjia`
- Need to start eclipse from command line, this is a
  #link("https://www.wfbsoftware.de/2019/01/12/eclipse-cdt-c-cmake-on-mac/")[bug]

In order to debug, basiclly eclipse only supports gdb, which is has been
replaced with lldb in MacOS, so a few setps needed to make it working:

- install gdb via mac ports, `sudo port install gdb`
- after installed, it's located in `/opt/local/bin/ggdb`
- create an alias for gdb in your bash profile(eg. `~/.zshrc`),
  `alias gdb=ggdb`
- codesign for gdb, following
  #link("https://www.thomasvitale.com/how-to-setup-gdb-and-eclipse-to-debug-c-files-on-macos-sierra/")[How to setup gdb and Eclipse to debug C++ files on macOS Mojave]
- create gdb init file: `echo "set startup-with-shell off" > ~/gdbinit`
- need to start eclipse from terminal, otherwise it will not recongnize
  gdb

Reference:

- #link("https://dev.to/acharluk/developing-c-with-visual-studio-code-4pb9")[Developing C++ with Visual Studio Code]
