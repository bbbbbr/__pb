; DMGTRIS
; Copyright (C) 2023 - Randy Thiemann <randy.thiemann@gmail.com>

; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.

; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.

; You should have received a copy of the GNU General Public License
; along with this program.  If not, see <https://www.gnu.org/licenses/>.


IF !DEF(STATE_TITLE_ASM)
DEF STATE_TITLE_ASM EQU 1


INCLUDE "globals.asm"
INCLUDE "res/title_data.inc"


SECTION "Title Variables", WRAM0
wSelected::  ds 1
wTitleMode:: ds 1
wProfileName:: ds 3


SECTION "Title Function Trampolines", ROM0
    ; Trampolines to the banked function.
SwitchToTitle::
    ld b, BANK_TITLE
    rst RSTSwitchBank
    call SwitchToTitleB
    jp RSTRestoreBank

    ; Banks and jumps to the actual handler.
TitleEventLoopHandler::
    ld b, BANK_TITLE
    rst RSTSwitchBank
    call TitleEventLoopHandlerB
    rst RSTRestoreBank
    jp EventLoopPostHandler

    ; Banks and jumps to the actual handler.
TitleVBlankHandler::
    ld b, BANK_TITLE
    rst RSTSwitchBank
    call TitleVBlankHandlerB
    rst RSTRestoreBank
    jp EventLoop

PersistLevel:
    ld b, BANK_OTHER
    rst RSTSwitchBank
    ld a, [hl+]
    ld [rSelectedStartLevel], a
    ld a, [hl]
    ld [rSelectedStartLevel+1], a
    jp RSTRestoreBank

DrawSpeedMain:
    ld b, BANK_OTHER
    rst RSTSwitchBank

    ldh a, [hStartSpeed]
    ld l, a
    ldh a, [hStartSpeed+1]
    ld h, a
    ld a, [hl]
    swap a
    and a, $0F
    ld b, a
    ld a, TILE_0
    add a, b
    ld hl, TITLE_MAIN_START+2
    ld [hl], a

    ldh a, [hStartSpeed]
    ld l, a
    ldh a, [hStartSpeed+1]
    ld h, a
    ld a, [hl]
    and a, $0F
    ld b, a
    ld a, TILE_0
    add a, b
    ld hl, TITLE_MAIN_START+3
    ld [hl], a

    ldh a, [hStartSpeed]
    ld l, a
    ldh a, [hStartSpeed+1]
    ld h, a
    inc hl
    ld a, [hl]
    swap a
    and a, $0F
    ld b, a
    ld a, TILE_0
    add a, b
    ld hl, TITLE_MAIN_START+0
    ld [hl], a

    ldh a, [hStartSpeed]
    ld l, a
    ldh a, [hStartSpeed+1]
    ld h, a
    inc hl
    ld a, [hl]
    and a, $0F
    ld b, a
    ld a, TILE_0
    add a, b
    ld hl, TITLE_MAIN_START+1
    ld [hl], a

    jp RSTRestoreBank

DrawSpeedSettings:
    ld b, BANK_OTHER
    rst RSTSwitchBank

    ldh a, [hStartSpeed]
    ld l, a
    ldh a, [hStartSpeed+1]
    ld h, a
    ld a, [hl]
    swap a
    and a, $0F
    ld b, a
    ld a, TILE_0
    add a, b
    ld hl, TITLE_SETTINGS_START+2
    ld [hl], a

    ldh a, [hStartSpeed]
    ld l, a
    ldh a, [hStartSpeed+1]
    ld h, a
    ld a, [hl]
    and a, $0F
    ld b, a
    ld a, TILE_0
    add a, b
    ld hl, TITLE_SETTINGS_START+3
    ld [hl], a

    ldh a, [hStartSpeed]
    ld l, a
    ldh a, [hStartSpeed+1]
    ld h, a
    inc hl
    ld a, [hl]
    swap a
    and a, $0F
    ld b, a
    ld a, TILE_0
    add a, b
    ld hl, TITLE_SETTINGS_START+0
    ld [hl], a

    ldh a, [hStartSpeed]
    ld l, a
    ldh a, [hStartSpeed+1]
    ld h, a
    inc hl
    ld a, [hl]
    and a, $0F
    ld b, a
    ld a, TILE_0
    add a, b
    ld hl, TITLE_SETTINGS_START+1
    ld [hl], a

    jp RSTRestoreBank


SECTION "Title Functions Banked", ROMX, BANK[BANK_TITLE]
SwitchToTitleB:
    ; Turn the screen off if it's on.
    ldh a, [rLCDC]
    and LCDCF_ON
    jr z, :+ ; Screen is already off.
    wait_vram
    xor a, a
    ldh [rLCDC], a

    ; And the tiles.
:   call LoadTitleTiles

    ; Zero out SCX.
    xor a, a
    ldh [rSCX], a

    ; No screen squish for title.
    call DisableScreenSquish

    ; Clear OAM.
    call ClearOAM

    ; Set up the palettes.
    ld a, PALETTE_INVERTED
    set_bg_palette
    set_obj0_palette
    set_obj1_palette

    ; Go to the correct title screen mode.
    ld a, TITLE_MAIN
    call SwitchTitleMode

    ; Music start
    call SFXKill
    ld a, MUSIC_MENU
    call SFXEnqueue

    ; Make sure the first game loop starts just like all the future ones.
    wait_vblank
    wait_vblank_end
    ret

SwitchTitleMode:
    ; Set title to mode in A.
    ld [wTitleMode], a
    ld a, STATE_TITLE
    ldh [hGameState], a
    xor a, a
    ld [wSelected], a

    ; Turn the screen off if it's on.
    ldh a, [rLCDC]
    and LCDCF_ON
    jr z, :+ ; Screen is already off.
    wait_vram
    xor a, a
    ldh [rLCDC], a

    ; Jump to correct handler.
:   ld b, 0
    ld a, [wTitleMode]
    ld c, a
    ld hl, .jumps
    add hl, bc
    jp hl

.jumps
    jp .switchMain
    jp .switchProfile
    jp .switchSettings
    jp .switchRecords
    jp .switchCredits


.switchMain
    ld de, sTitleScreenMainMap
    ld hl, $9800
    ld bc, sTitleScreenMainMapEnd - sTitleScreenMainMap
    call UnsafeMemCopy

    ; Title screen easter egg.
    ld a, [wInitialC]
    cp a, $14
    jr nz, .notsgb
    ld de, sEasterS0
    ld hl, EASTER_0
    ld bc, 5
    call UnsafeMemCopy
    ld de, sEasterS1
    ld hl, EASTER_1
    ld bc, 5
    call UnsafeMemCopy
    jr .done

.notsgb
    ld a, [wInitialA]
    cp a, $FF
    jr nz, .notmgb
    ld de, sEasterM0
    ld hl, EASTER_0
    ld bc, 5
    call UnsafeMemCopy
    ld de, sEasterM1
    ld hl, EASTER_1
    ld bc, 5
    call UnsafeMemCopy
    jr .done

.notmgb
    ld a, [wInitialA]
    cp a, $11
    jr nz, .done

    ld a, [wInitialB]
    bit 0, a
    jr nz, .agb
    ld de, sEasterC0
    ld hl, EASTER_0-1
    ld bc, 11
    call UnsafeMemCopy
    ld de, sEasterC1
    ld hl, EASTER_1-1
    ld bc, 11
    call UnsafeMemCopy
    jr .done

.agb
    ld de, sEasterA0
    ld hl, EASTER_0-1
    ld bc, 11
    call UnsafeMemCopy
    ld de, sEasterA1
    ld hl, EASTER_1-1
    ld bc, 11
    call UnsafeMemCopy
    jr .done

.done
    call GBCTitleInit
    ld a, LCDCF_ON | LCDCF_BGON | LCDCF_BLK01
    ldh [rLCDC], a
    ret

.switchProfile
    call GBCTitleInit
    ld a, LCDCF_ON | LCDCF_BGON | LCDCF_BLK01
    ldh [rLCDC], a
    ret

.switchSettings
    ld de, sTitleScreenSettingsMap
    ld hl, $9800
    ld bc, sTitleScreenSettingsMapEnd - sTitleScreenSettingsMap
    call UnsafeMemCopy
    call GBCTitleInit
    ld a, LCDCF_ON | LCDCF_BGON | LCDCF_BLK01
    ldh [rLCDC], a
    ret

.switchRecords
    call GBCTitleInit
    ld a, LCDCF_ON | LCDCF_BGON | LCDCF_BLK01
    ldh [rLCDC], a
    ret

.switchCredits
    call GBCTitleInit
    ld a, LCDCF_ON | LCDCF_BGON | LCDCF_BLK01
    ldh [rLCDC], a
    ret


    ; Event loop handlers for title screen.
TitleEventLoopHandlerB:
    call GBCTitleProcess

    ; Jump to the correct eventloop handler.
    ld b, 0
    ld a, [wTitleMode]
    ld c, a
    ld hl, .jumps
    add hl, bc
    jp hl

.jumps
    jp .eventLoopMain
    jp .eventLoopProfile
    jp .eventLoopSettings
    jp .eventLoopRecords
    jp .eventLoopCredits

.eventLoopMain
    ; A/Start?
    ldh a, [hAState]
    cp a, 1
    jp z, MainHandleA
    ldh a, [hStartState]
    cp a, 1
    jp z, MainHandleA

    ; Directions?
    ldh a, [hUpState]
    cp a, 1
    jp z, MainHandleUp
    cp a, 16
    jp c, .d0
    ldh a, [hFrameCtr]
    and 3
    cp a, 3
    jp z, MainHandleUp

.d0
    ldh a, [hDownState]
    cp a, 1
    jp z, MainHandleDown
    cp a, 16
    ret c
    ldh a, [hFrameCtr]
    and 3
    cp a, 3
    ret nz
    jp MainHandleDown

.eventLoopProfile
    ret

.eventLoopSettings
    ; A/Start?
    ldh a, [hAState]
    cp a, 1
    jp z, SettingsHandleA
    ldh a, [hStartState]
    cp a, 1
    jp z, SettingsHandleA

    ; B?
    ldh a, [hBState]
    cp a, 1
    jp z, SettingsHandleB

    ; Directions?
    ldh a, [hUpState]
    cp a, 1
    jp z, SettingsHandleUp
    cp a, 16
    jp c, .d1
    ldh a, [hFrameCtr]
    and 3
    cp a, 3
    jp z, SettingsHandleUp

.d1
    ldh a, [hDownState]
    cp a, 1
    jp z, SettingsHandleDown
    cp a, 16
    jp c, .l1
    ldh a, [hFrameCtr]
    and 3
    cp a, 3
    jp z, SettingsHandleDown

.l1
    ldh a, [hLeftState]
    cp a, 1
    jp z, SettingsHandleLeft
    cp a, 16
    jp c, .r1
    ldh a, [hLeftState]
    and 3
    cp a, 3
    jp z, SettingsHandleLeft

.r1
    ldh a, [hRightState]
    cp a, 1
    jp z, SettingsHandleRight
    cp a, 16
    ret c
    ldh a, [hRightState]
    and 3
    cp a, 3
    ret nz
    jp SettingsHandleRight

.eventLoopRecords
    ret

.eventLoopCredits
    ret


    ; VBLank handlers for title screen.
TitleVBlankHandlerB:
    call ToATTR

    ; Jump to the correct vblank handler.
    ld b, 0
    ld a, [wTitleMode]
    ld c, a
    ld hl, .jumps
    add hl, bc
    jp hl

.jumps
    jp .vblankMain
    jp .vblankProfile
    jp .vblankSettings
    jp .vblankRecords
    jp .vblankCredits

.vblankMain
    ; What is the current option?
    DEF option = 0
    REPT TITLE_MAIN_OPTIONS
        ld hl, TITLE_MAIN_OPTION_BASE+(32*option)
        ld a, [wSelected]
        cp a, option
        jr z, .selected\@
.notselected\@:
        ld a, TILE_UNSELECTED
        ld [hl], a
        jr .done\@
.selected\@:
        ld a, TILE_SELECTED
        ld [hl], a
.done\@:
        DEF option += 1
    ENDR

    ; RNG mode.
    ld b, 0
    ld a, [wRNGModeState]
    sla a
    sla a
    ld c, a
    ld hl, sRNGMode
    add hl, bc
    ld d, h
    ld e, l
    ld hl, TITLE_MAIN_RNG
    ld bc, 4
    call UnsafeMemCopy

    ; ROT mode.
    ld b, 0
    ld a, [wRotModeState]
    sla a
    sla a
    ld c, a
    ld hl, sROTMode
    add hl, bc
    ld d, h
    ld e, l
    ld hl, TITLE_MAIN_ROT
    ld bc, 4
    call UnsafeMemCopy

    ; DROP mode.
    ld b, 0
    ld a, [wDropModeState]
    sla a
    sla a
    ld c, a
    ld hl, sDROPMode
    add hl, bc
    ld d, h
    ld e, l
    ld hl, TITLE_MAIN_DROP
    ld bc, 4
    call UnsafeMemCopy

    ; CURVE mode.
    ld b, 0
    ld a, [wSpeedCurveState]
    sla a
    sla a
    ld c, a
    ld hl, sCURVEMode
    add hl, bc
    ld d, h
    ld e, l
    ld hl, TITLE_MAIN_SCURVE
    ld bc, 4
    call UnsafeMemCopy

    ; HIG mode.
    ld a, [wSpeedCurveState]
    cp a, SCURVE_DEAT
    jr z, .disabled
    cp a, SCURVE_SHIR
    jr z, .disabled
    xor a, a
    ld b, a
    ld a, [wAlways20GState]
    sla a
    sla a
    ld c, a
    ld hl, sHIGMode
    add hl, bc
    ld d, h
    ld e, l
    ld hl, TITLE_MAIN_HIG
    ld bc, 4
    call UnsafeMemCopy
    jr .profile
.disabled
    ld de, sDisabled
    ld hl, TITLE_MAIN_HIG
    ld bc, 4
    call UnsafeMemCopy

    ; PROFILE name.
.profile
    ld de, wProfileName
    ld hl, TITLE_MAIN_PROFILE
    ld bc, 3
    call UnsafeMemCopy

    ; START level.
    jp DrawSpeedMain

.vblankProfile
    ret

.vblankSettings
    ; What is the current option?
    DEF option = 0
    REPT TITLE_SETTINGS_OPTIONS
        ld hl, TITLE_SETTINGS_OPTION_BASE+(32*option)
        ld a, [wSelected]
        cp a, option
        jr z, .selected\@
.notselected\@:
        ld a, TILE_UNSELECTED
        ld [hl], a
        jr .done\@
.selected\@:
        ld a, TILE_SELECTED
        ld [hl], a
.done\@:
        DEF option += 1
    ENDR

    ; RNG mode.
    ld b, 0
    ld a, [wRNGModeState]
    sla a
    sla a
    ld c, a
    ld hl, sRNGMode
    add hl, bc
    ld d, h
    ld e, l
    ld hl, TITLE_SETTINGS_RNG
    ld bc, 4
    call UnsafeMemCopy

    ; ROT mode.
    ld b, 0
    ld a, [wRotModeState]
    sla a
    sla a
    ld c, a
    ld hl, sROTMode
    add hl, bc
    ld d, h
    ld e, l
    ld hl, TITLE_SETTINGS_ROT
    ld bc, 4
    call UnsafeMemCopy

    ; DROP mode.
    ld b, 0
    ld a, [wDropModeState]
    sla a
    sla a
    ld c, a
    ld hl, sDROPMode
    add hl, bc
    ld d, h
    ld e, l
    ld hl, TITLE_SETTINGS_DROP
    ld bc, 4
    call UnsafeMemCopy

    ; CURVE mode.
    ld b, 0
    ld a, [wSpeedCurveState]
    sla a
    sla a
    ld c, a
    ld hl, sCURVEMode
    add hl, bc
    ld d, h
    ld e, l
    ld hl, TITLE_SETTINGS_SCURVE
    ld bc, 4
    call UnsafeMemCopy

    ; HIG mode.
    ld a, [wSpeedCurveState]
    cp a, SCURVE_DEAT
    jr z, .disabled1
    cp a, SCURVE_SHIR
    jr z, .disabled1
    xor a, a
    ld b, a
    ld a, [wAlways20GState]
    sla a
    sla a
    ld c, a
    ld hl, sHIGMode
    add hl, bc
    ld d, h
    ld e, l
    ld hl, TITLE_SETTINGS_HIG
    ld bc, 4
    call UnsafeMemCopy
    jr .buttons
.disabled1
    ld de, sDisabled
    ld hl, TITLE_SETTINGS_HIG
    ld bc, 4
    call UnsafeMemCopy

.buttons
    ld b, 0
    ld a, [wSwapABState]
    sla a
    sla a
    ld c, a
    ld hl, sBUTTONSMode
    add hl, bc
    ld d, h
    ld e, l
    ld hl, TITLE_SETTINGS_BUTTONS
    ld bc, 4
    call UnsafeMemCopy

    ; START level.
    call DrawSpeedSettings

    ; Tetry!
    ld a, [wSelected]
    ld hl, sTetryButtons
    ld bc, 64
:   cp a, 0
    jr z, .donetetry
    dec a
    add hl, bc
    jr :-
.donetetry
    ld d, h
    ld e, l
    ld hl, TITLE_SETTINGS_TETRY
    ld bc, 16
    call SafeMemCopy
    ld hl, TITLE_SETTINGS_TETRY+(1*32)
    ld bc, 16
    call SafeMemCopy
    ld hl, TITLE_SETTINGS_TETRY+(2*32)
    ld bc, 16
    call SafeMemCopy
    ld hl, TITLE_SETTINGS_TETRY+(3*32)
    ld bc, 16
    jp SafeMemCopy

.vblankRecords
    ret

.vblankCredits
    ret


MainHandleA:
    ld a, [wSelected]
    ld b, a
    add a, b
    add a, b
    ld c, a
    ld b, 0
    ld hl, .jumps
    add hl, bc
    jp hl

.jumps
    jp SwitchToGameplay
    jp SwitchToGameplayBig
    no_jump
    jp .tosettings
    no_jump
    no_jump

.tosettings
    ld a, TITLE_SETTINGS
    jp SwitchTitleMode


MainHandleUp:
    ld a, [wSelected]
    cp a, 0
    jr z, :+
    dec a
    ld [wSelected], a
    ret
:   ld a, TITLE_MAIN_OPTIONS-1
    ld [wSelected], a
    ret


MainHandleDown:
    ld a, [wSelected]
    cp a, TITLE_MAIN_OPTIONS-1
    jr z, :+
    inc a
    ld [wSelected], a
    ret
:   xor a, a
    ld [wSelected], a
    ret


SettingsHandleA:
    ld a, [wSelected]
    cp a, TITLE_SETTINGS_SEL_BACK
    jp nz, SettingsHandleRight
    ld a, TITLE_MAIN
    jp SwitchTitleMode


SettingsHandleB:
    ld a, TITLE_MAIN
    jp SwitchTitleMode


SettingsHandleDown:
    ld a, [wSelected]
    cp a, TITLE_SETTINGS_OPTIONS-1
    jr z, :+
    inc a
    ld [wSelected], a
    ret
:   xor a, a
    ld [wSelected], a
    ret


SettingsHandleUp:
    ld a, [wSelected]
    cp a, 0
    jr z, :+
    dec a
    ld [wSelected], a
    ret
:   ld a, TITLE_SETTINGS_OPTIONS-1
    ld [wSelected], a
    ret


SettingsHandleLeft:
    ld a, [wSelected]
    cp a, TITLE_SETTINGS_SEL_BACK
    ret z

    ld b, a
    add a, b
    add a, b
    ld c, a
    ld b, 0
    ld hl, .jumps
    add hl, bc
    jp hl

.jumps
    jp .buttons
    jp .rng
    jp .rot
    jp .drop
    jp .curve
    jp .hig
    jp DecrementLevel
    no_jump

.buttons
    ld a, [wSwapABState]
    cp a, 0
    jr z, :+
    dec a
    ld [wSwapABState], a
    ld [rSwapABState], a
    ret
:   ld a, BUTTON_MODE_COUNT-1
    ld [wSwapABState], a
    ld [rSwapABState], a
    ret

.rng
    ld a, [wRNGModeState]
    cp a, 0
    jr z, :+
    dec a
    ld [wRNGModeState], a
    ld [rRNGModeState], a
    ret
:   ld a, RNG_MODE_COUNT-1
    ld [wRNGModeState], a
    ld [rRNGModeState], a
    ret

.rot
    ld a, [wRotModeState]
    cp a, 0
    jr z, :+
    dec a
    ld [wRotModeState], a
    ld [rRotModeState], a
    ret
:   ld a, ROT_MODE_COUNT-1
    ld [wRotModeState], a
    ld [rRotModeState], a
    ret

.drop
    ld a, [wDropModeState]
    cp a, 0
    jr z, :+
    dec a
    ld [wDropModeState], a
    ld [rDropModeState], a
    ret
:   ld a, DROP_MODE_COUNT-1
    ld [wDropModeState], a
    ld [rDropModeState], a
    ret

.curve
    ld a, [wSpeedCurveState]
    cp a, 0
    jr z, :+
    dec a
    ld [wSpeedCurveState], a
    ld [rSpeedCurveState], a
    call InitSpeedCurve
    ret
:   ld a, SCURVE_COUNT-1
    ld [wSpeedCurveState], a
    ld [rSpeedCurveState], a
    call InitSpeedCurve
    ret

.hig
    ld a, [wAlways20GState]
    cp a, 0
    jr z, :+
    dec a
    ld [wAlways20GState], a
    ld [rAlways20GState], a
    ret
:   ld a, HIG_MODE_COUNT-1
    ld [wAlways20GState], a
    ld [rAlways20GState], a
    ret


SettingsHandleRight:
    ld a, [wSelected]
    cp a, TITLE_SETTINGS_SEL_BACK
    ret z

    ld b, a
    add a, b
    add a, b
    ld c, a
    ld b, 0
    ld hl, .jumps
    add hl, bc
    jp hl

.jumps
    jp .buttons
    jp .rng
    jp .rot
    jp .drop
    jp .curve
    jp .hig
    jp IncrementLevel
    no_jump

.buttons
    ld a, [wSwapABState]
    cp a, BUTTON_MODE_COUNT-1
    jr z, :+
    inc a
    ld [wSwapABState], a
    ld [rSwapABState], a
    ret
:   xor a, a
    ld [wSwapABState], a
    ld [rSwapABState], a
    ret

.rng
    ld a, [wRNGModeState]
    cp a, RNG_MODE_COUNT-1
    jr z, :+
    inc a
    ld [wRNGModeState], a
    ld [rRNGModeState], a
    ret
:   xor a, a
    ld [wRNGModeState], a
    ld [rRNGModeState], a
    ret

.rot
    ld a, [wRotModeState]
    cp a, ROT_MODE_COUNT-1
    jr z, :+
    inc a
    ld [wRotModeState], a
    ld [rRotModeState], a
    ret
:   xor a, a
    ld [wRotModeState], a
    ld [rRotModeState], a
    ret

.drop
    ld a, [wDropModeState]
    cp a, DROP_MODE_COUNT-1
    jr z, :+
    inc a
    ld [wDropModeState], a
    ld [rDropModeState], a
    ret
:   xor a, a
    ld [wDropModeState], a
    ld [rDropModeState], a
    ret

.curve
    ld a, [wSpeedCurveState]
    cp a, SCURVE_COUNT-1
    jr z, :+
    inc a
    ld [wSpeedCurveState], a
    ld [rSpeedCurveState], a
    call InitSpeedCurve
    ret
:   xor a, a
    ld [wSpeedCurveState], a
    ld [rSpeedCurveState], a
    call InitSpeedCurve
    ret

.hig
    ld a, [wAlways20GState]
    cp a, HIG_MODE_COUNT-1
    jr z, :+
    inc a
    ld [wAlways20GState], a
    ld [rAlways20GState], a
    ret
:   xor a, a
    ld [wAlways20GState], a
    ld [rAlways20GState], a
    ret


    ; Decrements start level.
DecrementLevel:
    ; Decrement
    ldh a, [hStartSpeed]
    ld l, a
    ldh a, [hStartSpeed+1]
    ld h, a
    ld bc, -SCURVE_ENTRY_SIZE
    add hl, bc
    ld a, l
    ldh [hStartSpeed], a
    ld a, h
    ldh [hStartSpeed+1], a
    call PersistLevel
    jp CheckLevelRange


    ; Increments start level.
IncrementLevel:
    ; Increment
    ldh a, [hStartSpeed]
    ld l, a
    ldh a, [hStartSpeed+1]
    ld h, a
    ld bc, SCURVE_ENTRY_SIZE
    add hl, bc
    ld a, l
    ldh [hStartSpeed], a
    ld a, h
    ldh [hStartSpeed+1], a
    call PersistLevel
    jp CheckLevelRange


    ; Wipes the start level upon selecting a new speed curve.
InitSpeedCurve:
    ld a, [wSpeedCurveState]
    call GetStart
    ld a, l
    ldh [hStartSpeed], a
    ld a, h
    ldh [hStartSpeed+1], a
    jp PersistLevel


    ; Gets the end of a speed curve.
GetEnd:
    ld a, [wSpeedCurveState]
    cp a, SCURVE_DMGT
    jr nz, :+
    ld bc, sDMGTSpeedCurveEnd
    ret
:   cp a, SCURVE_TGM1
    jr nz, :+
    ld bc, sTGM1SpeedCurveEnd
    ret
:   cp a, SCURVE_TGM3
    jr nz, :+
    ld bc, sTGM3SpeedCurveEnd
    ret
:   cp a, SCURVE_DEAT
    jr nz, :+
    ld bc, sDEATSpeedCurveEnd
    ret
:   cp a, SCURVE_SHIR
    jr nz, :+
    ld bc, sSHIRSpeedCurveEnd
    ret
:   cp a, SCURVE_CHIL
    jr nz, :+
    ld bc, sCHILSpeedCurveEnd
    ret
:   ld bc, sMYCOSpeedCurveEnd
    ret


    ; Gets the beginning of a speed curve.
GetStart:
    ld a, [wSpeedCurveState]
    cp a, SCURVE_DMGT
    jr nz, :+
    ld hl, sDMGTSpeedCurve
    ret
:   cp a, SCURVE_TGM1
    jr nz, :+
    ld hl, sTGM1SpeedCurve
    ret
:   cp a, SCURVE_TGM3
    jr nz, :+
    ld hl, sTGM3SpeedCurve
    ret
:   cp a, SCURVE_DEAT
    jr nz, :+
    ld hl, sDEATSpeedCurve
    ret
:   cp a, SCURVE_SHIR
    jr nz, :+
    ld hl, sSHIRSpeedCurve
    ret
:   cp a, SCURVE_CHIL
    jr nz, :+
    ld hl, sCHILSpeedCurve
    ret
:   ld hl, sMYCOSpeedCurve
    ret


    ; Make sure we don't overflow the level range.
CheckLevelRange:
    ; At end?
    call GetEnd
    ldh a, [hStartSpeed]
    cp a, c
    jr nz, .notatend
    ldh a, [hStartSpeed+1]
    cp a, b
    jr nz, .notatend
    call GetStart
    ld a, l
    ldh [hStartSpeed], a
    ld a, h
    ldh [hStartSpeed+1], a
    call PersistLevel

.notatend
    ld de, -SCURVE_ENTRY_SIZE

    call GetStart
    add hl, de
    ldh a, [hStartSpeed]
    cp a, l
    jr nz, .notatstart
    ldh a, [hStartSpeed+1]
    cp a, h
    jr nz, .notatstart

    call GetEnd
    ld h, b
    ld l, c
    add hl, de
    ld a, l
    ldh [hStartSpeed], a
    ld a, h
    ldh [hStartSpeed+1], a
    call PersistLevel

.notatstart
    ret



ENDC
