class OsgeoGdalEcwjp2 < Formula
  desc "GDAL/OGR 2.x plugin for ECW driver"
  homepage "http://www.gdal.org/frmt_ecw.html"
  url "https://download.osgeo.org/gdal/2.4.1/gdal-2.4.1.tar.gz"
  sha256 "f1a11d1982205b9e4cc10e16f016a5559bfc9fa9a9ea69015e99ccd6a738ea4c"

  # revision 1

  head "https://github.com/OSGeo/gdal.git", :branch => "master"

  # bottle do
  #   never
  # end

  depends_on "osgeo-ecwjp2-sdk"
  depends_on "osgeo-gdal"

  def gdal_majmin_ver
    gdal_ver_list = Formula["osgeo-gdal"].version.to_s.split(".")
    "#{gdal_ver_list[0]}.#{gdal_ver_list[1]}"
  end

  def gdal_plugins_subdirectory
    "gdalplugins/#{gdal_majmin_ver}"
  end

  def install
    ENV.cxx11

    ecwjp2_opt = Formula["osgeo-ecwjp2-sdk"].opt_prefix
    ecwjp2_opt_include = ecwjp2_opt/"include/ECWJP2"

    gdal_plugins = lib/gdal_plugins_subdirectory
    gdal_plugins.mkpath

    # cxx flags
    args = %W[-Iport -Igcore -Ifrmts -DFRMT_ecw -DECWSDK_VERSION=53 -Ifrmts/ecw -DDO_NOT_USE_DEBUG_BOOL
              -I#{ecwjp2_opt_include} -I#{ecwjp2_opt_include}/NCSEcw/API
              -I#{ecwjp2_opt_include}/NCSEcw/ECW -I#{ecwjp2_opt_include}/NCSEcw/JP2]

    # source files
    Dir["frmts/ecw/*.cpp"].each do |src|
      args.concat %W[#{src}]
    end

    # plugin dylib
    dylib_name = "gdal_ECW_JP2ECW.dylib"
    args.concat %W[
      -dynamiclib
      -install_name #{opt_lib}/#{gdal_plugins_subdirectory}/#{dylib_name}
      -current_version #{version}
      -compatibility_version #{gdal_majmin_ver}.0
      -o #{gdal_plugins}/#{dylib_name}
      -undefined dynamic_lookup
    ]

    # ld flags
    args.concat %W[-L#{ecwjp2_opt}/lib -lNCSEcw]

    # build and install shared plugin
    system ENV.cxx, *args
  end

  def caveats; <<~EOS
      This formula provides a plugin that allows GDAL or OGR to access geospatial
      data stored in its format. In order to use the shared plugin, you may need
      to set the following enviroment variable:

        export GDAL_DRIVER_PATH=#{HOMEBREW_PREFIX}/lib/gdalplugins
    EOS
  end

  test do
    ENV["GDAL_DRIVER_PATH"] = "#{HOMEBREW_PREFIX}/lib/gdalplugins"
    gdal_opt_bin = Formula["osgeo-gdal"].opt_bin
    out = shell_output("#{gdal_opt_bin}/gdalinfo --formats")
    assert_match "ECW -raster- (rov)", out
    assert_match "JP2ECW -raster,vector- (rov)", out

    ecwjp2_test = Formula["osgeo-ecwjp2-sdk"].opt_prefix/"test"
    out = shell_output("#{gdal_opt_bin}/gdalinfo #{ecwjp2_test}/RGB_8bit.ecw")
    assert_match "Driver: ECW/ERDAS Compressed Wavelets", out
    assert_match "Size is 4320, 2160", out
    out = shell_output("#{gdal_opt_bin}/gdalinfo #{ecwjp2_test}/RGB_8bit.jp2")
    assert_match "Driver: JP2ECW/ERDAS JPEG2000", out
    assert_match "Size is 4320, 2160", out
  end
end
