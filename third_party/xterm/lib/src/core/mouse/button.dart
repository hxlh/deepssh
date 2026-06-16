enum TerminalMouseButton {
  left(id: 0),

  middle(id: 1),

  right(id: 2),

  // Mouse wheel buttons. Per the xterm mouse encoding, bit 6 (0x40 = 64)
  // marks a wheel event and the low two bits select the direction:
  //   64 = wheel up, 65 = wheel down, 66 = wheel left, 67 = wheel right.
  // The previous values (64+4..64+7 = 68..71) were invalid and were silently
  // ignored by applications, which is why wheel scrolling never worked even
  // for apps that request mouse reporting (e.g. Claude Code, vim).
  wheelUp(id: 64, isWheel: true),

  wheelDown(id: 65, isWheel: true),

  wheelLeft(id: 66, isWheel: true),

  wheelRight(id: 67, isWheel: true),
  ;

  /// The id that is used to report a button press or release to the terminal.
  final int id;

  /// Whether this button is a mouse wheel button.
  final bool isWheel;

  const TerminalMouseButton({required this.id, this.isWheel = false});
}
