import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:story_creator_plus/src/constants.dart';
import 'package:story_creator_plus/src/controller/editing_controller.dart';
import 'package:story_creator_plus/src/controller/utils.dart';
import 'package:story_creator_plus/src/enums/editable_item_type.dart';
import 'package:story_creator_plus/src/enums/editing_mode.dart';
import 'package:story_creator_plus/src/models/graphic_info.dart';
import 'package:story_creator_plus/src/views/paint_view.dart';
import 'package:story_creator_plus/src/helper/transformable.dart';
import 'package:story_creator_plus/src/widgets/text_dialog.dart';

class BackgroundImage extends StatefulWidget {
  final BuildContext? context;
  final File file;
  const BackgroundImage({Key? key, required this.file, this.context})
      : super(key: key);

  @override
  State<BackgroundImage> createState() => _BackgroundImageState();
}

class _BackgroundImageState extends State<BackgroundImage>
    with SingleTickerProviderStateMixin {
  final EditingController controller = Get.find<EditingController>();
  late AnimationController animationController;
  late Animation<double> animation;
  bool isAnimating = false;
  int currentTransformingWidget = -1;

  void _runAnimation() {
    animationController.forward().whenComplete(() {
      controller.editableItemInfo.removeAt(currentTransformingWidget);
      controller.isDeletionEligible = false;
      currentTransformingWidget = -1;
      setState(() {});
    });
  }

  checkIfDeletionEligible(int j, ScaleUpdateDetails d) {
    controller.isDeletionEligible = true;
    setState(() => currentTransformingWidget = j);
    if (d.focalPoint.dx <= Get.width / 3.5 &&
        d.focalPoint.dy < Get.width * Constants.editingBarHeightRatio + 50) {
      _runAnimation();
    }
  }

  @override
  void initState() {
    super.initState();
    animationController = AnimationController(
      duration: const Duration(seconds: 02),
      vsync: this,
    );
    animation = Tween<double>(begin: 1.5, end: 0.0).animate(
        CurvedAnimation(parent: animationController, curve: Curves.easeInOut));
    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        animationController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        // animationController.forward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    double sHeight = MediaQuery.of(context).size.height;
    double sWidth = MediaQuery.of(context).size.width;
    return RepaintBoundary(
      key: getScreenshotKey,
      child: Container(
          height: sHeight,
          width: sWidth,
          alignment: Alignment.center,
          margin: EdgeInsets.only(
              top: sHeight * Constants.editingBarHeightRatio,
              bottom: sHeight *
                  (Constants.captionBarHeightRatio),
          ),
          child: Obx(() => Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                fit: StackFit.expand,
                children: [Transform.rotate(
                          angle: controller.rotationAngle,
                          child: Center(
                            child: Container(
                              //NEEDS to be inside obx to update when rotation changes
                              constraints: controller.rotation == 1 ||
                                  controller.rotation == 3
                                  ? BoxConstraints.tightFor(
                                // this specific height and width so it gets fit when flipped
                                  height: Get.width * 0.95,
                                  width: Get.height * 0.80)
                                  : null,
                              child: Image.file(
                                controller.backgroundImage.path.isEmpty
                                    ? widget.file
                                    : controller.backgroundImage,
                                fit:BoxFit.contain,
                              ),
                            ),
                          ),
                        ),

                  //Paint Layer
                  //To Avoid Duplication of Painting Lines
                  Visibility(
                      visible: !(controller.editingModeSelected ==
                          EDITINGMODE.DRAWING),
                      child: const PaintView(shouldShowControls: false)),

                  //Graphic Layer
                  //Comprises of Stickers and Texts
                  for (int j = 0; j < controller.editableItemInfo.length; j++)
                    controller.editableItemInfo
                                .elementAt(j)!
                                .editableItemType ==
                            EditableItemType.text
                        ? TransformableWidget(
                            onTapDown: () {
                              TextDialog.show(
                                  context,
                                  TextEditingController(
                                      text: controller.editableItemInfo
                                          .elementAt(j)!
                                          .text!
                                          .text),
                                  Theme.of(context).textTheme.bodyMedium?.fontSize?? 20,
                                  controller.editableItemInfo
                                      .elementAt(j)!
                                      .text!
                                      .color,
                                  onFinished: (context) =>
                                      Navigator.of(context).pop(),
                                  onSubmitted: (String text) {
                                    controller.editableItemInfo[j] =
                                        EditableItem(
                                            editableItemType: controller
                                                .editableItemInfo
                                                .elementAt(j)!
                                                .editableItemType,
                                            text: controller.editableItemInfo
                                                .elementAt(j)!
                                                .text!
                                                .copyWith(text: text),
                                            matrixInfo: controller
                                                .editableItemInfo
                                                .elementAt(j)!
                                                .matrixInfo);
                                    controller.editingModeSelected =
                                        EDITINGMODE.NONE;
                                  });
                            },
                            onDetailsUpdate: (Matrix4 matrix4) {
                              controller.editableItemInfo[j] = EditableItem(
                                  editableItemType: controller.editableItemInfo
                                      .elementAt(j)!
                                      .editableItemType,
                                  text: controller.editableItemInfo
                                      .elementAt(j)!
                                      .text,
                                  matrixInfo: matrix4,
                                scaleFactor: controller.editableItemInfo
                                    .elementAt(j)!
                                    .scaleFactor,
                              );
                            },
                            onScaleStart: (details) {
                              setState(
                                  () => controller.editableItemInfo[j]?.
                                  scaleFactor = details.scale.toDouble());
                              checkIfDeletionEligible(j, details);
                            },
                            onScaleEnd: (d) {
                              controller.isDeletionEligible = false;
                            },
                            transform: controller.editableItemInfo
                                .elementAt(j)!
                                .matrixInfo,
                            child: ScaleTransition(
                              scale: currentTransformingWidget == j
                                  ? animation
                                  : Tween<double>(begin: 1.0, end: 1.0).animate(
                                      CurvedAnimation(
                                          parent: animationController,
                                          curve: Curves.easeInOut)),
                              child: Container(
                                constraints: const BoxConstraints(
                                    maxHeight: 100, minHeight: 100),
                                child: Text(
                                    controller.editableItemInfo
                                        .elementAt(j)!
                                        .text!
                                        .text,
                                    textAlign: TextAlign.center,
                                    maxLines: 4,
                                    textScaleFactor: controller.
                                      editableItemInfo[j]?.scaleFactor,
                                    softWrap: true,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium?.copyWith(
                                            color: controller.editableItemInfo
                                                .elementAt(j)!
                                                .text!
                                                .color)),
                              ),
                            ))
                        : controller.editableItemInfo
                                    .elementAt(j)!
                                    .editableItemType ==
                                EditableItemType.graphic
                            ? TransformableWidget(
                                onScaleStart: (details) {
                                  checkIfDeletionEligible(j, details);
                                },
                                onScaleEnd: (d) {
                                  controller.isDeletionEligible = false;
                                  setState(() {});
                                },
                                transform: controller.editableItemInfo
                                    .elementAt(j)!
                                    .matrixInfo,
                                onDetailsUpdate: (Matrix4 matrix4) {
                                  controller.editableItemInfo[j] = EditableItem(
                                      editableItemType: controller
                                          .editableItemInfo
                                          .elementAt(j)!
                                          .editableItemType,
                                      graphicImagePath: controller
                                          .editableItemInfo
                                          .elementAt(j)!
                                          .graphicImagePath,
                                      matrixInfo: matrix4,
                                    scaleFactor: controller.editableItemInfo
                                        .elementAt(j)!
                                        .scaleFactor,
                                  );
                                },
                                child: ScaleTransition(
                                    scale: currentTransformingWidget == j
                                        ? animation
                                        : Tween<double>(begin: 1.0, end: 1.0)
                                            .animate(CurvedAnimation(
                                                parent: animationController,
                                                curve: Curves.easeInOut)),
                                    child: Image.asset(
                                      controller.editableItemInfo
                                          .elementAt(j)!
                                          .graphicImagePath!,
                                      fit: BoxFit.contain,
                                    )))
                            : TransformableWidget(
                                onScaleStart: (details) {
                                  checkIfDeletionEligible(j, details);
                                },
                                onScaleEnd: (d) {
                                  controller.isDeletionEligible = false;
                                  setState(() {});
                                },
                                transform: controller.editableItemInfo
                                    .elementAt(j)!
                                    .matrixInfo,
                                onDetailsUpdate: (Matrix4 matrix4) {
                                  controller.editableItemInfo[j] = EditableItem(
                                      editableItemType: controller
                                          .editableItemInfo
                                          .elementAt(j)!
                                          .editableItemType,
                                      shapeSvg: controller.editableItemInfo
                                          .elementAt(j)!
                                          .shapeSvg,
                                      matrixInfo: matrix4);
                                },
                                child: ScaleTransition(
                                    scale: currentTransformingWidget == j
                                        ? animation
                                        : Tween<double>(begin: 1.0, end: 1.0)
                                            .animate(CurvedAnimation(
                                                parent: animationController,
                                                curve: Curves.easeInOut)),
                                    child: SvgPicture.string(
                                      controller.editableItemInfo
                                          .elementAt(j)!
                                          .shapeSvg!,
                                      height: 100,
                                      fit: BoxFit.fitWidth,
                                    ))),
                ],
              ))),
    );
  }
}
