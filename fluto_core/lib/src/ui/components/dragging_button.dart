import 'package:draggable_widget/draggable_widget.dart';
import 'package:fluto_core/src/provider/fluto_provider.dart';
import 'package:fluto_core/src/ui/components/fluto_plugin_sheet.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DraggingButton extends StatelessWidget {
  const DraggingButton({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final flutoProvider = context.read<FlutoProvider>();
    final showDraggingButton = context
        .select<FlutoProvider, bool>((value) => value.showDraggingButton);
    return DraggableWidget(
      bottomMargin: 120,
      topMargin: 120,
      intialVisibility: showDraggingButton,
      horizontalSpace: 5,
      shadowBorderRadius: 1,
      initialPosition: AnchoringPosition.bottomRight,
      dragController: flutoProvider.dragController,
      normalShadow: const BoxShadow(
          color: Colors.transparent, offset: Offset(0, 4), blurRadius: 2),
      child: FloatingActionButton.extended(
        backgroundColor: Colors.blueAccent,
        icon: const Icon(Icons.bug_report),
        label: const Text("Fluto"),
        onPressed: () {
          showFlutoBottomSheet(context);
        },
      ),
    );
  }
}
