import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

class RiveAnimationWidget extends StatelessWidget {
  final String animationName;
  final double width;
  final double height;

  const RiveAnimationWidget({
    Key? key,
    required this.animationName,
    this.width = 200,
    this.height = 200,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      child: RiveAnimation.asset(
        'assets/animations/$animationName.riv',
        fit: BoxFit.cover,
      ),
    );
  }
}

// A sample animated button using Rive
class RiveAnimatedButton extends StatefulWidget {
  final String animationName;
  final VoidCallback onPressed;
  final String label;
  final double width;
  final double height;

  const RiveAnimatedButton({
    Key? key,
    required this.animationName,
    required this.onPressed,
    required this.label,
    this.width = 200,
    this.height = 60,
  }) : super(key: key);

  @override
  _RiveAnimatedButtonState createState() => _RiveAnimatedButtonState();
}

class _RiveAnimatedButtonState extends State<RiveAnimatedButton> {
  late SMITrigger? _buttonTrigger;
  late SMIBool? _buttonHover;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _buttonTrigger?.change(true);
        widget.onPressed();
      },
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: RiveAnimation.asset(
          'assets/animations/${widget.animationName}.riv',
          fit: BoxFit.fill,
          onInit: (artboard) {
            final controller = StateMachineController.fromArtboard(
              artboard,
              'Button',
            );
            if (controller != null) {
              artboard.addController(controller);

              _buttonTrigger = controller.findSMI('trig') as SMITrigger?;
              _buttonHover = controller.findSMI('hover') as SMIBool?;
            }
          },
          alignment: Alignment.center,
        ),
      ),
    );
  }
}