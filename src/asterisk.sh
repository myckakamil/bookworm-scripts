echo "Asterisk installation script" 

if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root."
    exit 1
fi

apt-get update && apt-get -y install build-essential git curl wget libnewt-dev libssl-dev libncurses5-dev subversion libsqlite3-dev libjansson-dev libxml2-dev uuid-dev default-libmysqlclient-dev libedit-dev liblua5.2-dev lua5.4 libopus-dev xmlstarlet 

# Download and extract Asterisk
cd /usr/src/
wget http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-20-current.tar.gz
tar xvf asterisk-20-current.tar.gz
cd /usr/src/asterisk-20.*

# Configure and build Asterisk
./configure
contrib/scripts/get_mp3_source.sh
menuselect/menuselect --enable pbx_lua --enable codec_opus --enable codec_g729
make
make install
make config
make install-logrotate

cat >> /etc/asterisk/asterisk.conf <<EOF
[directories]
astetcdir => /etc/asterisk
astmoddir => /usr/lib/asterisk/modules
astvarlibdir => /var/lib/asterisk
astdbdir => /var/lib/asterisk
astkeydir => /var/lib/asterisk
astdatadir => /var/lib/asterisk
astagidir => /var/lib/asterisk/agi-bin
astspooldir => /var/spool/asterisk
astrundir => /var/run/asterisk
astlogdir => /var/log/asteriskroot
EOF


cat >> /etc/asterisk/logger.conf <<EOF
[general]

[logfiles]

console = verbose,notice,warning,error

messages = notice,warning,error
full = verbose,notice,warning,error,debug
security = security
EOF

cat >> /etc/asterisk/modules.conf <<EOF
[modules]
autoload = no

; This is a minimal module load. We are loading only the modules
; required for the Asterisk features used in the "Super Awesome
; Company" configuration.

; Applications

load = app_bridgewait.so
load = app_dial.so
load = app_playback.so
load = app_stack.so
load = app_verbose.so
load = app_voicemail.so
load = app_directory.so
load = app_confbridge.so
load = app_queue.so

; Bridging

load = bridge_builtin_features.so
load = bridge_builtin_interval_features.so
load = bridge_holding.so
load = bridge_native_rtp.so
load = bridge_simple.so
load = bridge_softmix.so

; Call Detail Records

load = cdr_custom.so

; Channel Drivers

load = chan_bridge_media.so
load = chan_pjsip.so

; Codecs

load = codec_opus.so
load = codec_gsm.so
load = codec_resample.so
load = codec_ulaw.so
load = codec_g722.so

; Formats

load = format_gsm.so
load = format_pcm.so
load = format_wav_gsm.so
load = format_wav.so

; Functions

load = func_callerid.so
load = func_cdr.so
load = func_pjsip_endpoint.so
load = func_sorcery.so
load = func_devstate.so
load = func_strings.so

; Core/PBX

load = pbx_config.so

; AEL
;load = res_ael_share.so
;load = pbx_ael.so

; Lua
load = pbx_lua.so

; Resources

load = res_http_websocket.so
load = res_musiconhold.so
load = res_pjproject.so
load = res_pjsip_acl.so
load = res_pjsip_authenticator_digest.so
load = res_pjsip_caller_id.so
load = res_pjsip_config_wizard.so
load = res_pjsip_dialog_info_body_generator.so
load = res_pjsip_diversion.so
load = res_pjsip_dtmf_info.so
load = res_pjsip_endpoint_identifier_anonymous.so
load = res_pjsip_endpoint_identifier_ip.so
load = res_pjsip_endpoint_identifier_user.so
load = res_pjsip_exten_state.so
load = res_pjsip_header_funcs.so
load = res_pjsip_logger.so
load = res_pjsip_messaging.so
load = res_pjsip_mwi_body_generator.so
load = res_pjsip_mwi.so
load = res_pjsip_nat.so
load = res_pjsip_notify.so
load = res_pjsip_one_touch_record_info.so
load = res_pjsip_outbound_authenticator_digest.so
load = res_pjsip_outbound_publish.so
load = res_pjsip_outbound_registration.so
load = res_pjsip_path.so
load = res_pjsip_pidf_body_generator.so
load = res_pjsip_pidf_digium_body_supplement.so
load = res_pjsip_pidf_eyebeam_body_supplement.so
load = res_pjsip_publish_asterisk.so
load = res_pjsip_pubsub.so
load = res_pjsip_refer.so
load = res_pjsip_registrar.so
load = res_pjsip_rfc3326.so
load = res_pjsip_sdp_rtp.so
load = res_pjsip_send_to_voicemail.so
load = res_pjsip_session.so
load = res_pjsip.so
load = res_pjsip_t38.so
load = res_pjsip_transport_websocket.so
load = res_pjsip_xpidf_body_generator.so
load = res_rtp_asterisk.so
load = res_sorcery_astdb.so
load = res_sorcery_config.so
load = res_sorcery_memory.so
load = res_sorcery_realtime.so
load = res_timing_timerfd.so
load = res_odbc.so
load = res_odbc_transaction.so

noload = res_hep.so
noload = res_hep_pjsip.so
noload = res_hep_rtcp.so
EOF

systemctl enable asterisk
systemctl restart asterisk