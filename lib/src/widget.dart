part of '../flutter_advanced_drawer.dart';

/// AdvancedDrawer widget.
class AdvancedDrawer extends StatefulWidget {
  const AdvancedDrawer({
    Key? key,
    required this.child,
    required this.drawer,
    required this.controller,
    this.openRatio = 0.75,
    this.animationDuration = const Duration(milliseconds: 250),
    this.animationCurve,
    required this.animationController,
    this.enableDrop = true,
  }) : super(key: key);

  /// Child widget. (Usually widget that represent a screen)
  final Widget child;

  /// Drawer widget. (Widget behind the [child]).
  final Widget drawer;

  /// Controller that controls widget state.
  final AdvancedDrawerController controller;

  /// Opening ratio.
  final double openRatio;

  /// Animation duration.
  final Duration animationDuration;

  /// Animation curve.
  final Curve? animationCurve;

  final bool enableDrop;

  /// Controller that controls widget animation.
  final AnimationController animationController;

  @override
  _AdvancedDrawerState createState() => _AdvancedDrawerState();
}

class _AdvancedDrawerState extends State<AdvancedDrawer> {
  late AnimationController _animationController;

  late Animation<Offset> _childSlideAnimation;

  late double _offsetValue;
  late Offset _freshPosition;

  bool _captured = false;
  Offset? _startPosition;
  Duration? _dragEndDuration;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  @override
  void didUpdateWidget(covariant AdvancedDrawer oldWidget) {
    _initControllers();

    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    final content = Stack(
      clipBehavior: Clip.none,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: widget.animationController,
              builder: (context, child) {
                if (widget.animationController.value <= 0.05 &&
                    false == _controller.value.visible) {
                  return const SizedBox();
                }
                return FractionalTranslation(
                  translation: Tween(
                    begin: const Offset(-1.1, 0.1),
                    end: const Offset(0, 0),
                  ).animate(widget.animationController).value,
                  child: child,
                );
              },
              child: FractionallySizedBox(
                widthFactor: widget.openRatio,
                child: widget.drawer,
              ),
            ),
          ),
        ),
        SlideTransition(
          position: _childSlideAnimation,
          textDirection: TextDirection.ltr,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              RepaintBoundary(child: widget.child),
              ValueListenableBuilder<AdvancedDrawerValue>(
                valueListenable: _controller,
                builder: (_, value, __) {
                  if (!value.visible) {
                    return const SizedBox();
                  }

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _controller.hideDrawer,
                      highlightColor: Colors.transparent,
                      child: Container(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
    if (false == widget.enableDrop) {
      return content;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: _handleDragStart,
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      onHorizontalDragCancel: _handleDragCancel,
      child: content,
    );
  }

  AdvancedDrawerController get _controller {
    return widget.controller;
  }

  void _initControllers() {
    _controller
      ..removeListener(_handleControllerChanged)
      ..addListener(_handleControllerChanged);

    _animationController = widget.animationController;

    _animationController.reverseDuration =
        _animationController.duration = widget.animationDuration;

    final parentAnimation = widget.animationCurve == null
        ? _animationController
        : CurveTween(curve: widget.animationCurve!).animate(
            _animationController,
          );

    _childSlideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(widget.openRatio, 0),
    ).animate(parentAnimation);
  }

  TickerFuture animationToForward() {
    return _animationController.animateTo(
      1,
      duration: _dragEndDuration ?? widget.animationDuration,
      curve: Curves.easeOutCubic,
    );
  }

  TickerFuture animationToReverse() {
    return _animationController.animateTo(
      0,
      duration: _dragEndDuration ?? widget.animationDuration,
      curve: Curves.easeOutCubic,
    );
  }

  void _handleControllerChanged() {
    (_controller.value.visible ? animationToForward() : animationToReverse())
        .then((_) {
      _dragEndDuration = null;
    });
  }

  void _handleDragStart(DragStartDetails details) {
    _captured = true;
    _startPosition = details.globalPosition;
    _offsetValue = _animationController.value;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_captured) return;

    final screenSize = MediaQuery.of(context).size;
    var sub = details.primaryDelta;
    if (null != sub) {
      sub = sub / screenSize.height;
      if (_animationController.value + sub <= -0.1) {
        _animationController.value = -0.1;
      } else if (_animationController.value + sub >= 1.1) {
        _animationController.value = 1.1;
      } else {
        _animationController.value += sub;
      }
    }
    _freshPosition = details.globalPosition;

    final diff = (_freshPosition - _startPosition!).dx;

    _animationController.value =
        _offsetValue + (diff / (screenSize.width * widget.openRatio));
  }

  void _handleDragEnd(DragEndDetails details) async {
    if (!_captured) return;

    _captured = false;

    var subTime = (details.primaryVelocity ?? 0) / 1000;
    if (subTime < 0) {
      subTime = -subTime;
    }
    if (subTime > 1) {
      subTime = 1;
    }
    _dragEndDuration = Duration(milliseconds: (150 * (2 - subTime)).toInt());
    if (_controller.value.visible) {
      // 已经打开
      if (_animationController.value <= 0.5 ||
          (_animationController.value <= 0.9 &&
              null != details.primaryVelocity &&
              details.primaryVelocity! <
                  -2400 * (0.6 - _animationController.value))) {
        // 切换关闭
        _dragEndDuration = _dragEndDuration! * 1.2;
        _controller.hideDrawer();
      } else {
        // 回退到打开状态
        _animationController.animateTo(
          1,
          duration: _dragEndDuration,
          curve: Curves.easeOutBack,
        );
      }
    } else {
      // 关闭状态
      if (_animationController.value >= 0.5 ||
          (_animationController.value >= 0.1 &&
              null != details.primaryVelocity &&
              details.primaryVelocity! >
                  2400 * (0.6 - _animationController.value))) {
        // 切换打开
        _dragEndDuration = _dragEndDuration! * 1.5;
        _controller.showDrawer();
      } else {
        // 回退未打开状态
        var subTime = (details.primaryVelocity ?? 0) / 1000;
        if (subTime < 0) {
          subTime = -subTime;
        }
        if (subTime > 1) {
          subTime = 1;
        }
        _animationController.animateTo(
          0,
          duration: _dragEndDuration,
          curve: Curves.easeOutBack,
        );
      }
    }
  }

  void _handleDragCancel() {
    _captured = false;
  }

  @override
  void dispose() {
    super.dispose();
  }
}
