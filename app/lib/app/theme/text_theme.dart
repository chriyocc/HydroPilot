import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeFiTextTheme {
  static final kHeadTextStyle = GoogleFonts.manrope(
    textStyle: const TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w700,
      height: 1.1,
    ),
  );

  static final kSubHeadTextStyle = GoogleFonts.manrope(
    textStyle: const TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      height: 1.2,
    ),
  );

  static final kSub2HeadTextStyle = GoogleFonts.manrope(
    textStyle: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      height: 1.2,
    ),
  );

  static final kBodyTextStyle = GoogleFonts.manrope(
    textStyle: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.4,
    ),
  );
}

const kCardShadow = BoxShadow(
  offset: Offset(0, 12),
  blurRadius: 30,
  color: Color(0x122E3D36),
);
