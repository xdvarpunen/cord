import 'package:flutter/material.dart';

import '../data/libyco_berber_scripts.dart';
import '../data/tuareg_scripts.dart';

/// Reusable Tifinagh reference tables, shared by the desktop side panel on
/// [TifinaghPage] and the full-screen tabbed [ReferencePage]. Ported from the
/// tifi project's reference page, with the Neo-Tifinagh tab removed.

const _mobileBreakpoint = 600.0;
const _glyphFontSize = 20.0;
const _glyphFontSizeMobile = 16.0;

/// Tuareg Tifinagh scripts table (Ahaggar, Ghat, Aïr, Azawagh, Adrar), with a
/// checkbox per region to show/hide its column. The checked set is `static`
/// so it survives leaving and reopening the table.
class TuaregTable extends StatefulWidget {
  const TuaregTable({super.key});

  @override
  State<TuaregTable> createState() => _TuaregTableState();
}

class _TuaregTableState extends State<TuaregTable> {
  static const _ipaColumnWidth = 64.0;
  static const _soundColumnWidth = 64.0;
  static const _regionColumnWidth = 96.0;
  static const _ipaColumnWidthMobile = 44.0;
  static const _soundColumnWidthMobile = 44.0;
  static const _regionColumnWidthMobile = 72.0;

  static final Map<String, bool> _visible = {
    for (final r in tuaregRegions) r: true,
  };

  @override
  Widget build(BuildContext context) {
    final shownRegions = tuaregRegions.where((r) => _visible[r]!).toList();
    final isMobile = MediaQuery.sizeOf(context).width < _mobileBreakpoint;
    final ipaWidth = isMobile ? _ipaColumnWidthMobile : _ipaColumnWidth;
    final soundWidth = isMobile ? _soundColumnWidthMobile : _soundColumnWidth;
    final regionWidth = isMobile ? _regionColumnWidthMobile : _regionColumnWidth;
    final glyphFontSize = isMobile ? _glyphFontSizeMobile : _glyphFontSize;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 4,
            children: [
              for (final region in tuaregRegions)
                InkWell(
                  onTap: () =>
                      setState(() => _visible[region] = !_visible[region]!),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _visible[region],
                        onChanged: (v) =>
                            setState(() => _visible[region] = v ?? true),
                      ),
                      Text(region),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final contentWidth =
                  ipaWidth + soundWidth + shownRegions.length * regionWidth;
              final width = contentWidth > constraints.maxWidth
                  ? contentWidth
                  : constraints.maxWidth;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: width,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        color:
                            Theme.of(context).colorScheme.surfaceContainerHighest,
                        alignment: Alignment.center,
                        child: _row(
                          shownRegions,
                          leading: [
                            _HeaderCell('IPA', ipaWidth),
                            _HeaderCell('Sound', soundWidth),
                          ],
                          regionCell: (region) =>
                              _HeaderCell(region, regionWidth),
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              for (final row in tuaregRows)
                                _row(
                                  shownRegions,
                                  leading: [
                                    _BodyCell(row.ipa, ipaWidth,
                                        style: const TextStyle(
                                            fontStyle: FontStyle.italic)),
                                    _BodyCell(row.sound, soundWidth,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                  ],
                                  regionCell: (region) => _BodyCell(
                                    row.glyphFor(region),
                                    regionWidth,
                                    style: TextStyle(
                                      fontFamily: 'NotoSansTifinagh',
                                      fontSize: glyphFontSize,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _row(
    List<String> shownRegions, {
    required List<Widget> leading,
    required Widget Function(String region) regionCell,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...leading,
        for (final region in shownRegions) regionCell(region),
      ],
    );
  }
}

/// The (Eastern/Dougga) Libyco-Berber alphabet — the ancient script ancestor
/// of Tifinagh. Predates Unicode's Tifinagh block, so each letter is a
/// bundled image instead of a font glyph; the Ahaggar/Neo-Tifinagh columns
/// are the closest modern equivalents, shown for comparison.
class LibycoBerberTable extends StatelessWidget {
  const LibycoBerberTable({super.key});

  static const _imageColumnWidth = 64.0;
  static const _transliterationColumnWidth = 92.0;
  static const _equivalentColumnWidth = 92.0;
  static const _imageColumnWidthMobile = 56.0;
  static const _transliterationColumnWidthMobile = 76.0;
  static const _equivalentColumnWidthMobile = 76.0;
  static const _imageSize = 28.0;
  static const _imageSizeMobile = 22.0;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < _mobileBreakpoint;
    final glyphFontSize = isMobile ? _glyphFontSizeMobile : _glyphFontSize;
    final imageSize = isMobile ? _imageSizeMobile : _imageSize;
    final imageColumnWidth =
        isMobile ? _imageColumnWidthMobile : _imageColumnWidth;
    final transliterationColumnWidth = isMobile
        ? _transliterationColumnWidthMobile
        : _transliterationColumnWidth;
    final equivalentColumnWidth =
        isMobile ? _equivalentColumnWidthMobile : _equivalentColumnWidth;

    return Column(
      children: [
        Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: _row(
            leading: [
              _HeaderCell('Letter', imageColumnWidth),
              _HeaderCell('Translit.', transliterationColumnWidth),
              _HeaderCell('Ahaggar', equivalentColumnWidth),
              _HeaderCell('Neo-Tif.', equivalentColumnWidth),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final row in libycoBerberRows)
                  _row(
                    leading: [
                      _BodyCell.child(
                        imageColumnWidth,
                        child: Image.asset(
                          'assets/tifi/libyco_berber/${row.asset}',
                          width: imageSize,
                          height: imageSize,
                        ),
                      ),
                      _BodyCell(row.transliteration, transliterationColumnWidth,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      _BodyCell(row.ahaggar, equivalentColumnWidth,
                          style: TextStyle(
                              fontFamily: 'NotoSansTifinagh',
                              fontSize: glyphFontSize)),
                      _BodyCell(row.neoTifinagh, equivalentColumnWidth,
                          style: TextStyle(
                              fontFamily: 'NotoSansTifinagh',
                              fontSize: glyphFontSize)),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _row({required List<Widget> leading}) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: leading,
      );
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.text, this.width);
  final String text;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _BodyCell extends StatelessWidget {
  const _BodyCell(this.text, this.width, {this.style}) : child = null;
  const _BodyCell.child(this.width, {required Widget this.child})
      : text = '',
        style = null;
  final String text;
  final double width;
  final TextStyle? style;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: child ?? Text(text, style: style),
      ),
    );
  }
}
