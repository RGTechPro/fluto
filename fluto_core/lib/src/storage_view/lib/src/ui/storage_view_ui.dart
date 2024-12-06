import 'dart:io';

import 'package:fluto_core/src/storage_view/lib/src/ui/controller/storage_viewer_controller.dart';
import 'package:fluto_core/src/storage_view/lib/src/ui/theme/storage_view_theme.dart';
import 'package:fluto_core/src/storage_view/lib/src/ui/utils/responsive_helper.dart';
import 'package:fluto_core/src/storage_view/lib/src/ui/widgets/forms/edit/edit_field_form.dart';
import 'package:fluto_core/src/storage_view/lib/src/ui/widgets/forms/filled_text_field/filled_text_field.dart';
import 'package:fluto_core/src/storage_view/lib/src/ui/widgets/modals/delete/delete_confirmation_modal.dart';
import 'package:fluto_core/src/storage_view/lib/src/ui/widgets/responsive/responsive_builder.dart';
import 'package:fluto_core/src/storage_view/lib/src/ui/widgets/storage_table.dart';
import 'package:flutter/material.dart';

class StorageView extends StatefulWidget {
  const StorageView({
    super.key,
    required this.storageViewerController,
    this.theme = const StorageViewTheme(),
  });

  final StorageViewTheme theme;
  final StorageViewerController storageViewerController;

  @override
  State<StorageView> createState() => _StorageViewState();
}

class _StorageViewState extends State<StorageView> {
  late final StorageViewerController _controller =
      widget.storageViewerController;

  final _searchController = TextEditingController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    _controller.load();
    _searchController.addListener(() {
      if (_searchController.text.isEmpty) {
        _controller.load();
      }
      _controller.search(_searchController.text);
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper.of(context);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: widget.theme.cardColor,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final storageEnties = _controller.data;
          return Theme(
            data: ThemeData(
              checkboxTheme:
                  widget.theme.checkboxTheme ?? _getDefaultCheckboxTheme(),
            ),
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  toolbarHeight: 70,
                  backgroundColor: widget.theme.cardColor,
                  automaticallyImplyLeading: false,
                  floating: true,
                  title: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Storage Viewer',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ],
                  ),
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(50),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 10),
                      child: FilledTextField(
                        controller: _searchController,
                        theme: widget.theme,
                        hintText: 'Search',
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: 
                  Platform.isIOS || Platform.isAndroid ?
                  ResponsiveBuilder(
                    largeScreen: (context) => Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StorageTable(
                          theme: widget.theme,
                          controller: _controller,
                          storageEnties: storageEnties,
                        ),
                        if (_controller.selectedEntry != null)
                          Expanded(
                            flex: 1,
                            child: EditFieldForm(
                              theme: widget.theme,
                              margin: EdgeInsets.zero,
                              entry: _controller.selectedEntry!,
                              onDeleted: () {
                                _controller
                                    .delete(_controller.selectedEntry!.key);
                              },
                              onUpdated: (value) {
                                _controller.update(
                                  _controller.selectedEntry!.key,
                                  value,
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                    smallScreen: (context) => SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: StorageTable(
                        theme: widget.theme,
                        controller: _controller,
                        storageEnties: storageEnties,
                      ),
                    ),
                  ):
                  StorageTable(
                    theme: widget.theme,
                    controller: _controller,
                    storageEnties: storageEnties,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 70)),
              ],
            ),
          );
        },
      ),
      floatingActionButton: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            if (_controller.isOneKeySelected) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 40,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final confirmDelete = await showDialog<bool>(
                              context: context,
                              builder: (context) => DeleteConfirmationModal(
                                theme: widget.theme,
                                title:
                                    'Are you realy want delete all this fields ?',
                              ),
                            );
                            if (confirmDelete ?? false) {
                              _controller.deleteSelectedEntries();
                            }
                          },
                          label: const Text('Delete all'),
                          icon: const Icon(Icons.delete),
                          style: ButtonStyle(
                            backgroundColor:
                                MaterialStateProperty.all(Colors.red),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 40,
                        child: ElevatedButton(
                          onPressed: () => _controller.toggleAllKeys(false),
                          child: const Text('Cacnel'),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox();
          }),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  _getDefaultCheckboxTheme() {
    return CheckboxThemeData(
      checkColor: MaterialStateProperty.all(Colors.white),
      side: MaterialStateBorderSide.resolveWith(
          (_) => const BorderSide(width: 1, color: Colors.white)),
    );
  }
}
