# Linux.Wifatch source repository

This is official Linux.Wifatch sources

This repository contain all local components (missing files are
unintentional and/or will be added later), additional C source code not
part of the botnet install, and selected C&C components. More can come
over time.

## Structure

* `bn/` is the binary botnet component, i.e. perl

* `pl/` is the perl botnet component

* `pl/bn/` is botnet modules

* `pl/fn/` is botnet commands (first argument on command line)

* `pl/tn/` is low-level botnet components, size-optimised

   * `pl/tn/pa.c` print-architecture, executed to see if architecture matches

   * `pl/tn/rf.c` receive-file, receive file on stdin, write to disk

   * `pl/tn/dl.c` download, download a file via botnet protocol

   * `pl/tn/tn.c` "telnet" - simple authenticated command/fileserver. last
     component installed before main botnet.

# Contact

In case of problem, question, missing files: ask, but do not expect speedy
reply!

The White Team <rav7teif@ya.ru>

# Q&A

* Why did you write this and let it go?

  First, for learning. Second, for understanding. Third, for fun, and
  fourth, for your (and our) security. Apart from the learning experience,
  this is a truly altruistic project, and no malicious actions are planned
  (and it nice touch that Symantec watch over this).

* Why release now?

  It was never intended to be secret. And to be truly ethical (Stallman
  said) it needs to have a free license (agree) and ask before acting (also
  agree, so only half way there).

* Why not release earlier?

  To avoid unwanted attention, especially by other mlaware authors who want
  to avoid detection. Plan failed, unwanted attention has been attracted, so
  release is fine.

* Who are you?

  We are nobody important. Really.

* Do you feel bad about abusing resources by others?

  Yes, although the amount of saved bandwidth by taking down other
  scanning malware, the amount energy saved by killing illegal bitcoin
  miners, the number of reboots and service interruptions prevented by
  not overheating these devices, the number of credentials and money not
  stolen should all outweigh this. We co-opted your devices to help the
  general public (in a small way).

* Can I trust you to not do evil things with my devices?

  Yes, but that is of no help - somebody could steal the key, no matter
  how well I protect it. More likely, there is a bug in the code that
  allows access to anybody.

* Should I trust you?

  Of course not, you should secure your device.

* Why is this not a problem?

  Linux.Wifatch doesn't use elaborate backdoors or 0day exploits to
  hack devices. It basically just uses telnet and a few other protocols
  and tries a few really dumb or default passwords (our favourite is
  "password"). These passwords are well-known - anybody can do that,
  without having to steal any secret key.

  Basically it only infects devices that are not protected at all in the
  first place!

* What license is this?

  Apart from some code copied from other sources (where marked), the intent
  is for all this code to be under the General Public License, version 3 or
  any later version. See the file `COPYING` for details.

* Where is the Stallman quote comment?

  There never was such a comment. The quote was used as telnet message for
  a short time. We agree with it, but found it a bit silly, so removed it
  quickly. Here is the quote:

  To any NSA and FBI agents reading my email: please consider
  whether defending the US Constitution against all enemies,
  foreign or domestic, requires you to follow Snowden's example.

* The passwords/secret keys are missing!

  Well, we hope they are missing. This release is for releasing the code,
  not to make it easy to hack others.

* Where is the infection code?

  Not here, it part of the command and control code. It might be released
  when it no longer is relevant, to protect the innocent.

* Where are the build scripts?

  Not part of the initial release.

* Is there a proof that this is the official repository?

  Here is a nistp256 signature of the sha256 of the repository URL on
  gitlab, using the actual signing key used for the real version.

  http://gitlab.com/rav7teif/linux.wifatch

  3678992952743f6596730c8936263ecdaca200f0aa87a3bf6d287561d1a55c4c
  a331e24b1d6aae7e8983adb9a9b9f68b3dc609278593bdbfbf60556a8acc42e2


