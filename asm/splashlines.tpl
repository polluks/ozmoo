splashline0 
	!pet "@0s@", 0
splashline1
	!pet "@1s@", 0
splashline2
	!pet "@2s@", 0
splashline3
	!pet "@3s@", 0
splashline4

!ifndef NODARKMODE {
	!ifdef SCROLLBACK {
		!pet " Ozmoo @vs@  F1=Darkmode F5=Scrollback",0
	} else {
		!pet "        Ozmoo @vs@   F1=Darkmode",0
	}
} else {
	!ifdef SCROLLBACK {
		!pet "       Ozmoo @vs@   F5=Scrollback",0
	} else {
		!pet "               Ozmoo @vs@",0
	}
}
splashline5
	!pet "  Ctrl: D=Reset device#, R=Repeat keys",0
splashline6
	!pet "            0-4=Scroll delay",0


splash_index_col
	!byte @0c@, @1c@, @2c@, @3c@, 0, 0, 0

