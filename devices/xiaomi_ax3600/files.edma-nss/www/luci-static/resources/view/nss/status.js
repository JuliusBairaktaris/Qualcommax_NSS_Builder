'use strict';
'require view';
'require fs';
'require poll';
'require dom';

// Renders the output of `nss-status -j` (the single source of truth for
// NSS plane health); this view only formats, it computes nothing itself.

function getStatus() {
	return fs.exec('/usr/sbin/nss-status', ['-j']).then(function(res) {
		if (res.code !== 0)
			throw new Error(res.stderr || 'nss-status failed');
		return JSON.parse(res.stdout);
	});
}

function stateBadge(state) {
	var map = {
		active:  ['#2e7d32', _('Offload active')],
		stalled: ['#c62828', _('Firmware armed but heartbeat silent — check the system log; a reboot returns to the host stack')],
		host:    ['#f9a825', _('Host stack (NSS plane not armed)')]
	};
	var m = map[state] || ['#757575', state];
	return E('div', {
		'style': 'display:inline-block;padding:.3em .8em;border-radius:.3em;color:#fff;font-weight:bold;background:' + m[0]
	}, m[1]);
}

function row(label, value) {
	return E('tr', { 'class': 'tr' }, [
		E('td', { 'class': 'td left', 'width': '30%' }, label),
		E('td', { 'class': 'td left' }, value)
	]);
}

function onoff(v) {
	return v ? _('loaded') : _('not loaded');
}

function renderStatus(d) {
	var cores = (d.cores || []).map(function(c) {
		return 'core' + c.core + ' ' + c.avg + '%';
	}).join(', ');

	var igs = (d.sqm.igs || []).map(function(i) {
		return i.port + (i.active ? ' ✓' : ' ✗');
	}).join('  ');

	var wifi = d.wifi_offload == 1 ? _('NSS offload active (wifili)') :
	           d.wifi_offload == 0 ? _('host mode') : _('ath11k not loaded');

	var portRows = (d.ports || []).map(function(p) {
		return E('tr', { 'class': 'tr' }, [
			E('td', { 'class': 'td' }, p.netdev),
			E('td', { 'class': 'td' }, String(p.ifnum)),
			E('td', { 'class': 'td' }, p.started ? _('yes') : _('no')),
			E('td', { 'class': 'td' }, String(p.tx_pkts)),
			E('td', { 'class': 'td' }, String(p.rx_fw_pkts))
		]);
	});

	return E('div', {}, [
		E('p', {}, stateBadge(d.state)),
		E('table', { 'class': 'table' }, [
			row(_('Firmware'), d.fw_version + ' (fw_mask ' + d.fw_mask + ')'),
			row(_('Heartbeat'), d.heartbeat_pps + ' ' + _('pkts/s (NSS→host)')),
			row(_('NSS core load'), cores || '-'),
			row(_('ECM accelerated connections'), d.ecm.loaded
				? d.ecm.ipv4_accel + ' IPv4 / ' + d.ecm.ipv6_accel + ' IPv6'
				: _('ECM not loaded')),
			row(_('Bridge offload (bridge-mgr)'), onoff(d.modules.bridge_mgr)),
			row(_('Multicast snooping (qca-mcs)'), onoff(d.modules.mcs)),
			row(_('PPPoE manager'), onoff(d.modules.pppoe)),
			row(_('Wi-Fi data path'), wifi),
			row(_('SQM shaper'), d.sqm.active
				? _('nsstbl on') + ' ' + d.sqm.device + (igs ? ' — ' + _('upload IGS:') + ' ' + igs : '')
				: _('no NSS shaper on') + ' ' + d.sqm.device)
		]),
		E('h3', {}, _('Firmware-attached ports')),
		E('table', { 'class': 'table' }, [
			E('tr', { 'class': 'tr table-titles' }, [
				E('th', { 'class': 'th' }, _('Port')),
				E('th', { 'class': 'th' }, 'if_num'),
				E('th', { 'class': 'th' }, _('Started')),
				E('th', { 'class': 'th' }, _('TX packets')),
				E('th', { 'class': 'th' }, _('RX from firmware'))
			])
		].concat(portRows.length ? portRows : [
			E('tr', { 'class': 'tr' }, [
				E('td', { 'class': 'td', 'colspan': '5' }, _('No ports attached — host stack'))
			])
		]))
	]);
}

return view.extend({
	load: getStatus,

	render: function(data) {
		var container = E('div', {}, renderStatus(data));

		poll.add(function() {
			return getStatus().then(function(d) {
				dom.content(container, renderStatus(d));
			});
		}, 10);

		return E('div', {}, [
			E('h2', {}, _('NSS Offload')),
			container
		]);
	},

	handleSave: null,
	handleSaveApply: null,
	handleReset: null
});
