#!/bin/sh
# ============================================================
#  แปลงธีม Telegram.sh
#  ตัวแปลงธีม Telegram (ทำงานได้บน iSH / Alpine / Linux / macOS)
#  ต้องการแค่ sh + awk + sed + grep (busybox ก็พอ)
#
#  โหมด 1  light   : ธีม iOS มืด (Catppuccin Mocha) -> สว่าง (Latte)
#  โหมด 2  android : ธีม Android (.attheme / .txt)  -> iOS (.tgios-theme)
#
#  วิธีใช้:
#    sh "แปลงธีม Telegram.sh"                      # เมนูโต้ตอบ
#    sh "แปลงธีม Telegram.sh" light   Mocha.tgios-theme [ผลลัพธ์]
#    sh "แปลงธีม Telegram.sh" android Vanilla.txt       [ผลลัพธ์]
# ============================================================

# ---------- ค่าที่ปรับแต่งได้ (โหมด android) ----------
OUTBUB="4B4268"    # สีฟองแชทขาออก (Android โปร่งแสง จึงใช้สีทึบแทน)
OUTBUBH="5A5080"   # สีฟองขาออกตอนกดค้าง/ไฮไลต์
DEFAULT_BG="110D1B"

# ---------- โฟลเดอร์ชั่วคราว + ลบทิ้งตอนจบ ----------
T=$(mktemp -d 2>/dev/null || { mkdir -p /tmp/tgconv.$$ && echo /tmp/tgconv.$$; })
trap 'rm -rf "$T"' EXIT INT TERM

# ---------- แม่แบบโครงคีย์ของ iOS (ฝังไว้ในสคริปต์) ----------
cat > "$T/template" <<'TEMPLATE_EOF'
name: 🌿 Mocha
shortname: ctp_mocha_ios
basedOn: night
dark: true
intro_statusBar: white
intro_primaryText: #CDD6F4
intro_accentText: #6B9968
intro_disabledText: #575B55
intro_startButton: #A6E3A1
intro_dot: #BAC2DE
passcode_bg_top: #585B70
passcode_bg_bottom: #1E1E2E
passcode_button: #313244
root_statusBar: white
root_tabBar_background: #313244
root_tabBar_separator: #11111B
root_tabBar_icon: #7F849C
root_tabBar_selectedIcon: #6B9968
root_tabBar_text: #7F849C
root_tabBar_selectedText: #6B9968
root_tabBar_badgeBackground: #F38BA8
root_tabBar_badgeStroke: #F38BA8
root_tabBar_badgeText: #11111B
root_navBar_button: #6B9968
root_navBar_disabledButton: #575B55
root_navBar_primaryText: #CDD6F4
root_navBar_secondaryText: #BAC2DE
root_navBar_control: #BAC2DE
root_navBar_accentText: #6B9968
root_navBar_background: #313244
root_navBar_opaqueBackground: #313244
root_navBar_separator: #11111B
root_navBar_badgeFill: #F38BA8
root_navBar_badgeStroke: #F38BA8
root_navBar_badgeText: #11111B
root_navBar_segmentedBg: #1E1E2E
root_navBar_segmentedFg: #313244
root_navBar_segmentedText: #CDD6F4
root_navBar_segmentedDivider: #CDD6F47F
root_searchBar_background: #313244
root_searchBar_accent: #6B9968
root_searchBar_inputFill: #1E1E2E
root_searchBar_inputText: #CDD6F4
root_searchBar_inputPlaceholderText: #BAC2DE
root_searchBar_inputIcon: #BAC2DE
root_searchBar_inputClearButton: #BAC2DE
root_searchBar_separator: #1E1E2E
root_keyboard: dark
list_blocksBg: #1E1E2E
list_plainBg: #1E1E2E
list_primaryText: #CDD6F4
list_secondaryText: #CDD6F47F
list_disabledText: #CDD6F47F
list_accent: #6B9968
list_highlighted: #A6E3A1
list_destructive: #F38BA8
list_placeholderText: #CDD6F47F
list_itemBlocksBg: #313244
list_itemHighlightedBg: #313244
list_blocksSeparator: #11111B
list_plainSeparator: #11111B
list_disclosureArrow: #CDD6F47F
list_sectionHeaderText: #585B70
list_freeText: #585B70
list_freeTextError: #F38BA8
list_freeTextSuccess: #A6E3A1
list_freeMonoIcon: #585B70
list_switch_frame: #CDD6F47F
list_switch_handle: #11111B
list_switch_content: #A6E3A1
list_switch_positive: #A6E3A1
list_switch_negative: #F38BA8
list_disclosureActions_neutral1_bg: #A6E3A1
list_disclosureActions_neutral1_fg: #FFFFFF
list_disclosureActions_neutral2_bg: #FAB387
list_disclosureActions_neutral2_fg: #FFFFFF
list_disclosureActions_destructive_bg: #F38BA8
list_disclosureActions_destructive_fg: #FFFFFF
list_disclosureActions_constructive_bg: #A6E3A1
list_disclosureActions_constructive_fg: #FFFFFF
list_disclosureActions_accent_bg: #6B9968
list_disclosureActions_accent_fg: #FFFFFF
list_disclosureActions_warning_bg: #FAB387
list_disclosureActions_warning_fg: #FFFFFF
list_disclosureActions_inactive_bg: #1E1E2E
list_disclosureActions_inactive_fg: #CDD6F4
list_check_bg: #6B9968
list_check_stroke: #CDD6F47F
list_check_fg: #11111B
list_controlSecondary: #CDD6F47F
list_freeInputField_bg: #313244
list_freeInputField_stroke: #313244
list_freeInputField_placeholder: #CDD6F47F
list_freeInputField_primary: #CDD6F4
list_freeInputField_control: #CDD6F47F
list_mediaPlaceholder: #1E1E2E
list_scrollIndicator: #CDD6F47F
list_pageIndicatorInactive: #CDD6F466
list_inputClearButton: #BAC2DE
list_itemBarChart_color1: #6B9968
list_itemBarChart_color2: #CDD6F47F
list_itemBarChart_color3: #1E1E2E
list_itemInputField_bg: #181825
list_itemInputField_stroke: #181825
list_itemInputField_placeholder: #7F849C
list_itemInputField_primary: #CDD6F4
list_itemInputField_control: #7F849C
chatList_bg: #1E1E2E
chatList_itemSeparator: #11111B
chatList_itemBg: #1E1E2E
chatList_pinnedItemBg: #313244
chatList_itemHighlightedBg: #313244
chatList_pinnedItemHighlightedBg: #313244
chatList_itemSelectedBg: #313244
chatList_title: #CDD6F4
chatList_secretTitle: #A6E3A1
chatList_dateText: #CDD6F47F
chatList_authorName: #CDD6F4
chatList_messageText: #CDD6F47F
chatList_messageHighlightedText: #CDD6F4
chatList_messageDraftText: #F38BA8
chatList_checkmark: #A6E3A1
chatList_pendingIndicator: #CDD6F466
chatList_failedFill: #F38BA8
chatList_failedFg: #CDD6F4
chatList_muteIcon: #CDD6F466
chatList_unreadBadgeActiveBg: #6B9968
chatList_unreadBadgeActiveText: #11111B
chatList_unreadBadgeInactiveBg: #CDD6F466
chatList_unreadBadgeInactiveText: #1E1E2E
chatList_reactionBadgeActiveBg: #F38BA8
chatList_pinnedBadge: #CDD6F47F
chatList_pinnedSearchBar: #1E1E2E
chatList_regularSearchBar: #313244
chatList_sectionHeaderBg: #313244
chatList_sectionHeaderText: #CDD6F47F
chatList_verifiedIconBg: #A6E3A1
chatList_verifiedIconFg: #CDD6F4
chatList_secretIcon: #A6E3A1
chatList_pinnedArchiveAvatar_background_top: #89B4FA
chatList_pinnedArchiveAvatar_background_bottom: #89B4FA
chatList_pinnedArchiveAvatar_foreground: #CDD6F4
chatList_unpinnedArchiveAvatar_background_top: #585B70
chatList_unpinnedArchiveAvatar_background_bottom: #585B70
chatList_unpinnedArchiveAvatar_foreground: #1E1E2E
chatList_onlineDot: #A6E3A1
chatList_storyUnseen_top: #34C76F
chatList_storyUnseen_bottom: #3DA1FD
chatList_storyUnseenPrivate_top: #7CD636
chatList_storyUnseenPrivate_bottom: #26B470
chatList_storySeen_top: #D8D8E1
chatList_storySeen_bottom: #D8D8E1
chat_animateMessageColors: false
chat_message_incoming_bubble_withWp_bg: #313244
chat_message_incoming_bubble_withWp_gradientBg: #313244
chat_message_incoming_bubble_withWp_highlightedBg: #313244
chat_message_incoming_bubble_withWp_stroke: #313244
chat_message_incoming_bubble_withWp_reactionInactiveBg: #6B996819
chat_message_incoming_bubble_withWp_reactionInactiveFg: #6B9968
chat_message_incoming_bubble_withWp_reactionActiveBg: #6B9968
chat_message_incoming_bubble_withWp_reactionActiveFg: clear
chat_message_incoming_bubble_withWp_reactionInactiveMediaPlaceholder: #FFFFFF33
chat_message_incoming_bubble_withWp_reactionActiveMediaPlaceholder: #FFFFFF33
chat_message_incoming_bubble_withoutWp_bg: #313244
chat_message_incoming_bubble_withoutWp_gradientBg: #313244
chat_message_incoming_bubble_withoutWp_highlightedBg: #313244
chat_message_incoming_bubble_withoutWp_stroke: #313244
chat_message_incoming_bubble_withoutWp_reactionInactiveBg: #6B996819
chat_message_incoming_bubble_withoutWp_reactionInactiveFg: #6B9968
chat_message_incoming_bubble_withoutWp_reactionActiveBg: #6B9968
chat_message_incoming_bubble_withoutWp_reactionActiveFg: clear
chat_message_incoming_bubble_withoutWp_reactionInactiveMediaPlaceholder: #FFFFFF33
chat_message_incoming_bubble_withoutWp_reactionActiveMediaPlaceholder: #FFFFFF33
chat_message_incoming_primaryText: #CDD6F4
chat_message_incoming_secondaryText: #CDD6F47F
chat_message_incoming_linkText: #A6E3A1
chat_message_incoming_linkHighlight: #A6E3A17F
chat_message_incoming_scam: #F38BA8
chat_message_incoming_textHighlight: #FAB387
chat_message_incoming_accentText: #6B9968
chat_message_incoming_accentControl: #6B9968
chat_message_incoming_mediaActiveControl: #6B9968
chat_message_incoming_mediaInactiveControl: #A6E3A17F
chat_message_incoming_mediaControlInnerBg: #313244
chat_message_incoming_pendingActivity: #CDD6F47F
chat_message_incoming_fileTitle: #6B9968
chat_message_incoming_fileDescription: #CDD6F47F
chat_message_incoming_fileDuration: #CDD6F47F
chat_message_incoming_mediaPlaceholder: #1E1E2E
chat_message_incoming_polls_radioButton: #585B70
chat_message_incoming_polls_radioProgress: #6B9968
chat_message_incoming_polls_highlight: #6B99681E
chat_message_incoming_polls_separator: #11111B
chat_message_incoming_polls_bar: #6B9968
chat_message_incoming_polls_barIconForeground: #CDD6F4
chat_message_incoming_polls_barPositive: #A6E3A1
chat_message_incoming_polls_barNegative: #F38BA8
chat_message_incoming_actionButtonsBg_withWp: #1E1E2E7F
chat_message_incoming_actionButtonsBg_withoutWp: #1E1E2E7F
chat_message_incoming_actionButtonsStroke_withWp: #6C708626
chat_message_incoming_actionButtonsStroke_withoutWp: #6C708626
chat_message_incoming_actionButtonsText_withWp: #CDD6F4
chat_message_incoming_actionButtonsText_withoutWp: #CDD6F4
chat_message_incoming_textSelection: #6B996833
chat_message_incoming_textSelectionKnob: #6B9968
chat_message_outgoing_bubble_withWp_bg: #A6E3A1
chat_message_outgoing_bubble_withWp_gradientBg: #A6E3A1
chat_message_outgoing_bubble_withWp_highlightedBg: #91CA8D
chat_message_outgoing_bubble_withWp_stroke: clear
chat_message_outgoing_bubble_withWp_reactionInactiveBg: #25AD0D19
chat_message_outgoing_bubble_withWp_reactionInactiveFg: #25AD0D
chat_message_outgoing_bubble_withWp_reactionActiveBg: #25AD0D
chat_message_outgoing_bubble_withWp_reactionActiveFg: clear
chat_message_outgoing_bubble_withWp_reactionInactiveMediaPlaceholder: #FFFFFF33
chat_message_outgoing_bubble_withWp_reactionActiveMediaPlaceholder: #FFFFFF33
chat_message_outgoing_bubble_withoutWp_bg: #A6E3A1
chat_message_outgoing_bubble_withoutWp_gradientBg: #A6E3A1
chat_message_outgoing_bubble_withoutWp_highlightedBg: #91CA8D
chat_message_outgoing_bubble_withoutWp_stroke: clear
chat_message_outgoing_bubble_withoutWp_reactionInactiveBg: #25AD0D19
chat_message_outgoing_bubble_withoutWp_reactionInactiveFg: #25AD0D
chat_message_outgoing_bubble_withoutWp_reactionActiveBg: #25AD0D
chat_message_outgoing_bubble_withoutWp_reactionActiveFg: clear
chat_message_outgoing_bubble_withoutWp_reactionInactiveMediaPlaceholder: #FFFFFF33
chat_message_outgoing_bubble_withoutWp_reactionActiveMediaPlaceholder: #FFFFFF33
chat_message_outgoing_primaryText: #000000
chat_message_outgoing_secondaryText: #077C00CC
chat_message_outgoing_linkText: #004BAD
chat_message_outgoing_linkHighlight: #004BAD4C
chat_message_outgoing_scam: #FF3B30
chat_message_outgoing_textHighlight: #FAB387
chat_message_outgoing_accentText: #119400
chat_message_outgoing_accentControl: #25AD0D
chat_message_outgoing_mediaActiveControl: #25AD0D
chat_message_outgoing_mediaInactiveControl: #79C160
chat_message_outgoing_mediaControlInnerBg: clear
chat_message_outgoing_pendingActivity: #077C00CC
chat_message_outgoing_fileTitle: #289715
chat_message_outgoing_fileDescription: #599E49
chat_message_outgoing_fileDuration: #077C00CC
chat_message_outgoing_mediaPlaceholder: #96D790
chat_message_outgoing_polls_radioButton: #79C160
chat_message_outgoing_polls_radioProgress: #25AD0D
chat_message_outgoing_polls_highlight: #25AD0D1E
chat_message_outgoing_polls_separator: #79C160
chat_message_outgoing_polls_bar: #25AD0D
chat_message_outgoing_polls_barIconForeground: clear
chat_message_outgoing_polls_barPositive: #25AD0D
chat_message_outgoing_polls_barNegative: #25AD0D
chat_message_outgoing_actionButtonsBg_withWp: #1E1E2E7F
chat_message_outgoing_actionButtonsBg_withoutWp: #1E1E2E7F
chat_message_outgoing_actionButtonsStroke_withWp: #6C708626
chat_message_outgoing_actionButtonsStroke_withoutWp: #6C708626
chat_message_outgoing_actionButtonsText_withWp: #CDD6F4
chat_message_outgoing_actionButtonsText_withoutWp: #CDD6F4
chat_message_outgoing_textSelection: #A3C57B
chat_message_outgoing_textSelectionKnob: #25AD0D
chat_message_freeform_withWp_bg: #313244
chat_message_freeform_withWp_gradientBg: #313244
chat_message_freeform_withWp_highlightedBg: #313244
chat_message_freeform_withWp_stroke: #313244
chat_message_freeform_withWp_reactionInactiveBg: #313244E5
chat_message_freeform_withWp_reactionInactiveFg: #CDD6F4
chat_message_freeform_withWp_reactionActiveBg: #89B4FA
chat_message_freeform_withWp_reactionActiveFg: #CDD6F4
chat_message_freeform_withWp_reactionInactiveMediaPlaceholder: #11111B19
chat_message_freeform_withWp_reactionActiveMediaPlaceholder: #11111B19
chat_message_freeform_withoutWp_bg: #313244
chat_message_freeform_withoutWp_gradientBg: #313244
chat_message_freeform_withoutWp_highlightedBg: #313244
chat_message_freeform_withoutWp_stroke: #313244
chat_message_freeform_withoutWp_reactionInactiveBg: #313244E5
chat_message_freeform_withoutWp_reactionInactiveFg: #CDD6F4
chat_message_freeform_withoutWp_reactionActiveBg: #89B4FA
chat_message_freeform_withoutWp_reactionActiveFg: #CDD6F4
chat_message_freeform_withoutWp_reactionInactiveMediaPlaceholder: #11111B19
chat_message_freeform_withoutWp_reactionActiveMediaPlaceholder: #11111B19
chat_message_infoPrimaryText: #CDD6F4
chat_message_infoLinkText: #A6E3A1
chat_message_outgoingCheck: #077C00CC
chat_message_mediaDateAndStatusBg: #11111B4C
chat_message_mediaDateAndStatusText: #CDD6F4
chat_message_shareButtonBg_withWp: #1E1E2E7F
chat_message_shareButtonBg_withoutWp: #1E1E2E7F
chat_message_shareButtonStroke_withWp: #6C708626
chat_message_shareButtonStroke_withoutWp: #6C708626
chat_message_shareButtonFg_withWp: #9399B2
chat_message_shareButtonFg_withoutWp: #9399B2
chat_message_mediaOverlayControl_bg: #11111B99
chat_message_mediaOverlayControl_fg: #CDD6F4
chat_message_selectionControl_bg: #6B9968
chat_message_selectionControl_stroke: #CDD6F4
chat_message_selectionControl_fg: #CDD6F4
chat_message_deliveryFailed_bg: #F38BA8
chat_message_deliveryFailed_fg: #CDD6F4
chat_message_mediaHighlightOverlay: #CDD6F499
chat_message_stickerPlaceholder_withWp: #3132447F
chat_message_stickerPlaceholder_withoutWp: #3132447F
chat_message_stickerPlaceholderShimmer_withWp: #CDD6F40C
chat_message_stickerPlaceholderShimmer_withoutWp: #CDD6F40C
chat_serviceMessage_components_withDefaultWp_bg: #1E1E2E
chat_serviceMessage_components_withDefaultWp_primaryText: #CDD6F4
chat_serviceMessage_components_withDefaultWp_linkHighlight: #CDD6F41E
chat_serviceMessage_components_withDefaultWp_scam: #F38BA8
chat_serviceMessage_components_withDefaultWp_dateFillStatic: #1E1E2E99
chat_serviceMessage_components_withDefaultWp_dateFillFloat: #1E1E2E33
chat_serviceMessage_components_withCustomWp_bg: #1E1E2E
chat_serviceMessage_components_withCustomWp_primaryText: #CDD6F4
chat_serviceMessage_components_withCustomWp_linkHighlight: #CDD6F41E
chat_serviceMessage_components_withCustomWp_scam: #F38BA8
chat_serviceMessage_components_withCustomWp_dateFillStatic: #1E1E2E99
chat_serviceMessage_components_withCustomWp_dateFillFloat: #1E1E2E33
chat_serviceMessage_unreadBarBg: #313244
chat_serviceMessage_unreadBarStroke: #313244
chat_serviceMessage_unreadBarText: #CDD6F4
chat_serviceMessage_dateText_withWp: #CDD6F4
chat_serviceMessage_dateText_withoutWp: #CDD6F4
chat_inputPanel_panelBg: #313244
chat_inputPanel_panelSeparator: #11111B
chat_inputPanel_panelControlAccent: #6B9968
chat_inputPanel_panelControl: #CDD6F47F
chat_inputPanel_panelControlDisabled: #7F849C7F
chat_inputPanel_panelControlDestructive: #F38BA8
chat_inputPanel_inputBg: #1E1E2E
chat_inputPanel_inputStroke: #1E1E2E
chat_inputPanel_inputPlaceholder: #CDD6F466
chat_inputPanel_inputText: #CDD6F4
chat_inputPanel_inputControl: #CDD6F466
chat_inputPanel_actionControlBg: #6B9968
chat_inputPanel_actionControlFg: #11111B
chat_inputPanel_primaryText: #CDD6F4
chat_inputPanel_secondaryText: #CDD6F47F
chat_inputPanel_mediaRecordDot: #A6E3A1
chat_inputPanel_mediaRecordControl_button: #6B9968
chat_inputPanel_mediaRecordControl_micLevel: #6B996833
chat_inputPanel_mediaRecordControl_activeIcon: #CDD6F4
chat_inputMediaPanel_panelSeparator: #313244
chat_inputMediaPanel_panelIcon: #CDD6F47F
chat_inputMediaPanel_panelHighlightedIconBg: #CDD6F41F
chat_inputMediaPanel_panelHighlightedIcon: #CDD6F4AC
chat_inputMediaPanel_panelContentVibrantOverlay: #CDD6F47F
chat_inputMediaPanel_panelContentControlVibrantOverlay: #CDD6F44C
chat_inputMediaPanel_panelContentControlVibrantSelection: #CDD6F419
chat_inputMediaPanel_panelContentControlOpaqueOverlay: #CDD6F44C
chat_inputMediaPanel_panelContentControlOpaqueSelection: #CDD6F44C
chat_inputMediaPanel_panelContentVibrantSearchOverlay: #9999998C
chat_inputMediaPanel_panelContentVibrantSearchOverlaySelected: #66666699
chat_inputMediaPanel_panelContentVibrantSearchOverlayHighlight: #33333305
chat_inputMediaPanel_panelContentOpaqueSearchOverlay: #8E8E93
chat_inputMediaPanel_panelContentOpaqueSearchOverlaySelected: #00000066
chat_inputMediaPanel_panelContentOpaqueSearchOverlayHighlight: #00000019
chat_inputMediaPanel_stickersBg: #1E1E2E
chat_inputMediaPanel_stickersSectionText: #CDD6F47F
chat_inputMediaPanel_stickersSearchBg: #6C7086
chat_inputMediaPanel_stickersSearchPlaceholder: #6C7086
chat_inputMediaPanel_stickersSearchPrimary: #CDD6F4
chat_inputMediaPanel_stickersSearchControl: #6C7086
chat_inputMediaPanel_gifsBg: #1E1E2E
chat_inputMediaPanel_bg: #1E1E2EBF
chat_inputButtonPanel_panelBg: #11111B
chat_inputButtonPanel_panelSeparator: #313244
chat_inputButtonPanel_buttonBg: #45475A
chat_inputButtonPanel_buttonHighlight: #FFFFFF33
chat_inputButtonPanel_buttonStroke: #11111B
chat_inputButtonPanel_buttonHighlightedBg: #45475AB2
chat_inputButtonPanel_buttonHighlightedStroke: #11111B
chat_inputButtonPanel_buttonText: #CDD6F4
chat_historyNav_bg: #313244
chat_historyNav_stroke: #11111B
chat_historyNav_fg: #CDD6F47F
chat_historyNav_badgeBg: #6B9968
chat_historyNav_badgeStroke: #6B9968
chat_historyNav_badgeText: #CDD6F4
wallpaper: #11111B
actionSheet_dim: #11111B7F
actionSheet_bgType: dark
actionSheet_opaqueItemBg: #313244
actionSheet_itemBg: #313244CC
actionSheet_opaqueItemHighlightedBg: #313244
actionSheet_itemHighlightedBg: #31324433
actionSheet_opaqueItemSeparator: #1E1E2E
actionSheet_standardActionText: #6B9968
actionSheet_destructiveActionText: #F38BA8
actionSheet_disabledActionText: #CDD6F47F
actionSheet_primaryText: #CDD6F4
actionSheet_secondaryText: #CDD6F47F
actionSheet_controlAccent: #6B9968
actionSheet_inputBg: #1E1E2E
actionSheet_inputHollowBg: #1E1E2E
actionSheet_inputBorder: #1E1E2E
actionSheet_inputPlaceholder: #BAC2DE
actionSheet_inputText: #CDD6F4
actionSheet_inputClearButton: #BAC2DE
actionSheet_checkContent: #11111B
contextMenu_dim: #11111B99
contextMenu_background: #313244C6
contextMenu_itemSeparator: #CDD6F426
contextMenu_sectionSeparator: #11111B33
contextMenu_itemBg: #11111B00
contextMenu_itemHighlightedBg: #CDD6F426
contextMenu_primary: #CDD6F4
contextMenu_secondary: #CDD6F47F
contextMenu_destructive: #F38BA8
notification_bg: #313244
notification_primaryText: #CDD6F4
notification_expanded_bgType: dark
notification_expanded_navBar_background: #313244
notification_expanded_navBar_primaryText: #CDD6F4
notification_expanded_navBar_control: #A6E3A1
notification_expanded_navBar_separator: #11111B
chart_labels: #A6ADC899
chart_helperLines: #7F849C59
chart_strongLines: #7F849C59
chart_barStrongLines: #A6ADC872
chart_detailsText: #CDD6F4
chart_detailsArrow: #CDD6F4
chart_detailsView: #181825
chart_rangeViewFrame: #45475A
chart_rangeViewMarker: #CDD6F4
TEMPLATE_EOF

# ---------- โปรแกรม awk ตัวแปลงหลัก ----------
cat > "$T/conv.awk" <<'AWK_EOF'
# อ่าน 3 ไฟล์ตามลำดับ: (1) ตารางแมปสี (2) ค่า override (3) ไฟล์ธีมต้นทาง
function conv(s,   out, h) {
  out = ""
  # วนหาสีรูปแบบ #RRGGBB ทุกจุดในบรรทัด (alpha 2 หลักท้ายจะคงไว้เอง)
  while (match(s, /#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]/)) {
    h = toupper(substr(s, RSTART + 1, 6))
    out = out substr(s, 1, RSTART) ((h in M) ? M[h] : h)
    s = substr(s, RSTART + RLENGTH)
  }
  return out s
}
BEGIN { n = split(ONSUF, SUF, " ") }
FNR == 1 { f++ }
f == 1 { if (NF >= 2) M[toupper($1)] = toupper($2); next }
f == 2 { i = index($0, "="); if (i) O[substr($0, 1, i - 1)] = substr($0, i + 1); next }
{
  sub(/\r$/, "")
  i = index($0, ":")
  if (i == 0) { print; next }
  key = substr($0, 1, i - 1); val = substr($0, i + 1)
  # 1) คีย์ที่กำหนดค่าเอง
  if (key in O) { print key ": " O[key]; next }
  # 2) เส้นแบ่ง (และ stroke ที่ไม่ใช่ของฟองแชท ถ้าเปิด STROKE)
  if (index(val, "#") && (key ~ /[Ss]eparator$/ || (STROKE == 1 && key ~ /_stroke$/ && key !~ /bubble/))) {
    print key ": " SEP; next
  }
  # 3) ตัวอักษร/ไอคอนที่อยู่บนพื้นสี accent
  on = 0
  for (j = 1; j <= n; j++) {
    s = SUF[j]
    if (length(key) >= length(s) && substr(key, length(key) - length(s) + 1) == s) on = 1
  }
  if (on) { print key ": " ONC; next }
  # 4) แมปสีทั่วไป
  print key ":" conv(val)
}
AWK_EOF

# รัน awk: run_conv <map> <override> <ธีมต้นทาง> <ผลลัพธ์> <ONC> <SEP> <STROKE>
run_conv() {
  awk -v ONC="$5" -v SEP="$6" -v STROKE="$7" \
      -v ONSUF="badgeText unreadBadgeActiveText actionControlFg list_check_fg list_switch_handle actionSheet_checkContent" \
      -f "$T/conv.awk" "$1" "$2" "$3" > "$4"
}

# ============================================================
#  โหมด 1: มืด (Mocha) -> สว่าง (Latte)
# ============================================================
do_light() {
  IN=$1; OUT=$2
  # ตารางแมปสี Mocha -> Latte
  cat > "$T/map" <<'EOF'
CDD6F4 4C4F69
BAC2DE 5C5F77
A6ADC8 6C6F85
9399B2 7C7F93
7F849C 8C8FA1
6C7086 9CA0B0
585B70 ACB0BE
45475A BCC0CC
313244 CCD0DA
1E1E2E EFF1F5
181825 E6E9EF
11111B DCE0E8
A6E3A1 40A02B
6B9968 40A02B
F38BA8 D20F39
FAB387 FE640B
89B4FA 1E66F5
91CA8D A9D99A
575B55 9CA0B0
EOF
  # คีย์ที่กำหนดค่าเอง เพื่อให้คอนทราสต์ดีในโหมดสว่าง
  cat > "$T/ovr" <<'EOF'
name=☕ Latte
shortname=ctp_latte_ios
basedOn=day
dark=false
intro_statusBar=black
root_statusBar=black
root_keyboard=light
actionSheet_bgType=light
notification_expanded_bgType=light
wallpaper=#DCE0E8
actionSheet_dim=#4C4F697F
contextMenu_dim=#4C4F6999
list_itemBlocksBg=#FFFFFF
list_itemHighlightedBg=#E6E9EF
chat_message_incoming_bubble_withWp_bg=#FFFFFF
chat_message_incoming_bubble_withWp_gradientBg=#FFFFFF
chat_message_incoming_bubble_withWp_stroke=#FFFFFF
chat_message_incoming_bubble_withoutWp_bg=#FFFFFF
chat_message_incoming_bubble_withoutWp_gradientBg=#FFFFFF
chat_message_incoming_bubble_withoutWp_stroke=#FFFFFF
chat_message_outgoing_bubble_withWp_bg=#BFE8B0
chat_message_outgoing_bubble_withWp_gradientBg=#BFE8B0
chat_message_outgoing_bubble_withoutWp_bg=#BFE8B0
chat_message_outgoing_bubble_withoutWp_gradientBg=#BFE8B0
chat_message_incoming_linkText=#1E66F5
chat_message_infoLinkText=#1E66F5
EOF
  # ตัวอักษรบน accent = ขาว, เส้นแบ่ง = เทาอ่อน
  run_conv "$T/map" "$T/ovr" "$IN" "$OUT" "#FFFFFF" "#CCD0DA" 1
}

# ============================================================
#  โหมด 2: Android -> iOS
# ============================================================
# ดึงสี 6 หลักจากไฟล์ Android: acol <ชื่อคีย์> <ค่าเริ่มต้น>
acol() {
  v=$(tr -d '\r' < "$AND" | grep -m1 "^$1:" | sed 's/^[^:]*:[ ]*#*//' | cut -c1-6 | tr 'a-f' 'A-F')
  if [ ${#v} -eq 6 ]; then echo "$v"; else echo "$2"; fi
}
# ดึงค่าข้อความทั้งบรรทัดจาก Android: atext <ชื่อคีย์> <ค่าเริ่มต้น>
atext() {
  v=$(tr -d '\r' < "$AND" | grep -m1 "^$1:" | sed 's/^[^:]*:[ ]*//')
  if [ -n "$v" ]; then echo "$v"; else echo "$2"; fi
}

do_android() {
  AND=$1; OUT=$2
  # พาเลตหลักอ่านจากไฟล์ Android
  BG=$(acol windowBackgroundWhite "$DEFAULT_BG")   # พื้นหลัง
  SURF=$(acol player_actionBar 2E2A39)             # พื้นผิวยกระดับ (แถบ/ฟองขาเข้า)
  SURF2=$(acol chat_inFileBackground 3C3848)
  ACCENT=$(acol dialogTextBlue 97A8CD)             # สีเน้นหลัก
  TEAL=$(acol checkbox 98BCB3)                     # สีติ๊กถูก/สถานะบวก
  LINK=$(acol chat_messageLinkIn 77AECD)           # สีลิงก์
  RED=$(acol chats_draft CD505A)
  ORANGE=$(acol avatar_backgroundOrange CCA55A)
  BLUE=$(acol chat_attachLocationBackground 88B1F3)
  TXT=$(acol chat_messageTextIn FAFAFA)            # ข้อความหลัก
  SUB=$(acol chats_message 8A8797)                 # ข้อความรอง
  # ตารางแมปสี Mocha (แม่แบบ) -> สีของธีม Android
  cat > "$T/map" <<EOF
CDD6F4 $TXT
BAC2DE 9996A8
A6ADC8 $SUB
9399B2 868395
7F849C 767285
6C7086 6D697D
585B70 524E60
45475A $SURF2
313244 $SURF
1E1E2E $BG
181825 130F1E
11111B $BG
A6E3A1 $TEAL
6B9968 $ACCENT
F38BA8 $RED
FAB387 $ORANGE
89B4FA $BLUE
91CA8D $OUTBUBH
25AD0D $TEAL
077C00 B3ADDB
119400 E5E2FC
79C160 B3ADDB
289715 FFFFFF
599E49 B3ADDB
96D790 6F6594
A3C57B 9E93DD
004BAD $LINK
575B55 6D697D
EOF
  # คีย์ที่กำหนดค่าเอง
  {
    echo "name=$(atext name 'Converted Theme')"
    echo "shortname=$(atext shortname 'converted_theme')"
    echo "chat_message_outgoing_primaryText=#FFFFFF"
    echo "chat_message_outgoing_linkText=#$LINK"
    echo "chat_message_incoming_linkText=#$LINK"
    echo "chat_message_infoLinkText=#$LINK"
    echo "chat_message_outgoingCheck=#$TEAL"
    echo "wallpaper=$(atext wallpaper "#$BG")"      # ใช้วอลเปเปอร์เดิม
    for g in withWp withoutWp; do                    # ฟองขาออกแบบทึบ
      echo "chat_message_outgoing_bubble_${g}_bg=#$OUTBUB"
      echo "chat_message_outgoing_bubble_${g}_gradientBg=#$OUTBUB"
    done
  } > "$T/ovr"
  # ตัวอักษรบน accent = สีพื้นหลังเข้ม, เส้นแบ่ง = ม่วงเข้มจาง
  run_conv "$T/map" "$T/ovr" "$T/template" "$OUT" "#$BG" "#2A2636" 0
}

# ---------- ตัวช่วย ----------
# ตัดเครื่องหมายคำพูดครอบ path (เวลาลากไฟล์มาวาง)
clean() { printf '%s' "$1" | sed "s/^['\"]//; s/['\"]\$//"; }
# ตั้งชื่อไฟล์ผลลัพธ์ถ้าไม่ได้ระบุ: <ชื่อเดิม><คำต่อท้าย>.tgios-theme
outname() { printf '%s%s.tgios-theme' "${1%.*}" "$2"; }

# ---------- เมนูโต้ตอบ ----------
MODE=$1
if [ -z "$MODE" ]; then
  echo "แปลงธีม Telegram"
  echo "  1) มืด -> สว่าง   (iOS Mocha -> Latte)"
  echo "  2) Android -> iOS (.attheme / .txt -> .tgios-theme)"
  printf "เลือก [1/2]: "; read -r CH
  case "$CH" in 1) MODE=light ;; 2) MODE=android ;; *) echo "ยกเลิก"; exit 1 ;; esac
  printf "path ไฟล์ธีมต้นทาง: "; read -r IN; IN=$(clean "$IN")
  printf "path ไฟล์ผลลัพธ์ (เว้นว่าง = อัตโนมัติ): "; read -r OUT; OUT=$(clean "$OUT")
else
  IN=$(clean "$2"); OUT=$(clean "$3")
fi

if [ -z "$IN" ] || [ ! -f "$IN" ]; then
  echo "ไม่พบไฟล์ต้นทาง: $IN" >&2; exit 1
fi

case "$MODE" in
  light|1)
    [ -z "$OUT" ] && OUT=$(outname "$IN" "-Latte")
    grep -q '^dark: *true' "$IN" || echo "คำเตือน: ไฟล์นี้ไม่ใช่ธีมมืด ผลลัพธ์อาจไม่ตรงตามคาด" >&2
    do_light "$IN" "$OUT" ;;
  android|2)
    [ -z "$OUT" ] && OUT=$(outname "$IN" "-ios")
    do_android "$IN" "$OUT" ;;
  *) echo "โหมดไม่ถูกต้อง: $MODE (ใช้ light หรือ android)" >&2; exit 1 ;;
esac

echo "เสร็จแล้ว: $OUT ($(wc -l < "$OUT") บรรทัด)"
