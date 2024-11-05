{
  mkDerivation,
  boot-config,
  pkgsBuildTarget,
  baseConfig ? "GENERIC",
}:
mkDerivation {
  path = "sys/arch/amd64";
  pname = "sys";
  extraPaths = [ "sys" ];
  noLibc = true;

  extraNativeBuildInputs = [
    boot-config
  ];

  postPatch = ''
    # The in-kernel debugger (DDB) requires compiler flags not supported by clang, disable it
    sed -E -i -e '/DDB/d' $BSDSRCDIR/sys/conf/GENERIC
    sed -E -i -e '/pseudo-device\tdt/d' $BSDSRCDIR/sys/arch/amd64/conf/GENERIC
    find $BSDSRCDIR -name 'Makefile*' -exec sed -E -i -e 's/-fno-ret-protector/-fno-stack-protector/g' -e 's/-nopie/-no-pie/g' {} +
    sed -E -i -e 's_^\tinstall.*$_\tinstall bsd ''${out}/bsd_' -e s/update-link// $BSDSRCDIR/sys/arch/*/conf/Makefile.*
    sed -E -i -e 's/^PAGE_SIZE=.*$/PAGE_SIZE=4096/g' -e '/^random_uniform/a echo 0; return 0;' $BSDSRCDIR/sys/conf/makegap.sh
    sed -E -i -e 's/^v=.*$/v=0 u=nixpkgs h=nixpkgs t=`date -d @1`/g' $BSDSRCDIR/sys/conf/newvers.sh
  '';

  postConfigure = ''
    export BSDOBJDIR=$TMP/obj
    mkdir $BSDOBJDIR
    make obj

    cd conf
    config ${baseConfig}
    cd -
  '';

  preBuild = ''
    # A lot of files insist on calling unprefixed `ld` and `objdump`.
    # It's easier to add them to PATH than patch and substitute.
    mkdir $TMP/bin
    export PATH=$TMP/bin:$PATH
    ln -s ${pkgsBuildTarget.binutils}/bin/${pkgsBuildTarget.binutils.targetPrefix}objdump $TMP/bin/objdump
    ln -s ${pkgsBuildTarget.binutils}/bin/${pkgsBuildTarget.binutils.targetPrefix}ld $TMP/bin/ld

    cd compile/${baseConfig}/obj

    # The Makefile claims it needs includes, but it really doesn't.
    # Tell it includes aren't real and can't hurt it.
    echo 'includes:' >>Makefile
  '';

  # stand is in a separate package
  env.SKIPDIR = "stand";
  env.NIX_CFLAGS_COMPILE = "-Wno-unused-command-line-argument -Wno-visibility";
}
