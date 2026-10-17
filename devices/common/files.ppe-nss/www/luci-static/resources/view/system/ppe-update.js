'use strict';
'require view';
'require form';
'require fs';
'require ui';

function fmtTime(t) {
	return t ? new Date(t * 1000).toLocaleString() : '-';
}

return view.extend({
	load: function() {
		return fs.exec_direct('/usr/sbin/ppe-update', [ 'status' ], 'json').catch(function(e) {
			return { error: e.message };
		});
	},

	pollLog: function() {
		return fs.read('/tmp/ppe-update.log').catch(function() { return ''; }).then(L.bind(function(log) {
			var box = document.getElementById('ppe-update-log');
			if (box)
				box.textContent = log;
			if (/flashing /.test(log))
				return ui.awaitReconnect();
			if (/^exit [1-9]/m.test(log)) {
				ui.addNotification(null, E('p', _('The update stopped; see the log above.')), 'error');
				return ui.hideModal();
			}
			return new Promise(function(r) { window.setTimeout(r, 2000); }).then(L.bind(this.pollLog, this));
		}, this));
	},

	startUpdate: function(st) {
		ui.showModal(_('Updating to %s').format(st.latest), [
			E('p', { 'class': 'spinning' }, _('Downloading and checking the image. The router flashes it and reboots; settings and added packages are kept.')),
			E('pre', { 'id': 'ppe-update-log', 'style': 'max-height:12em;overflow:auto;white-space:pre-wrap' })
		]);
		return fs.exec('/usr/sbin/ppe-update', [ 'start' ]).then(L.bind(this.pollLog, this));
	},

	render: function(st) {
		var m, s, o, rows = [];

		if (st.error && !st.current)
			rows.push([ _('Status'), st.error ]);
		rows.push([ _('Board'), st.board || '-' ]);
		rows.push([ _('Installed release'), st.current || _('not a builder image') ]);
		if (st.latest) {
			rows.push([ _('Newest release'), '%s (%s)'.format(st.latest, fmtTime(st.latest_time)) ]);
			if (st.extras)
				rows.push([ _('Reinstalled after the update'), st.extras ]);
		}
		else if (st.error) {
			rows.push([ _('Newest release'), st.error ]);
		}

		var status = E('div', { 'class': 'cbi-section' }, [
			E('h3', _('Firmware update')),
			E('p', { 'class': 'cbi-section-descr' },
				_('Installs the newest image of the builder this router came from. Settings stay, and packages added on top of the image are installed again after the reboot.')),
			E('table', { 'class': 'table' }, rows.map(function(r) {
				return E('tr', { 'class': 'tr' }, [ E('td', { 'class': 'td left', 'width': '33%' }, r[0]), E('td', { 'class': 'td left' }, r[1]) ]);
			})),
			E('div', { 'class': 'right' }, [
				st.update
					? E('button', { 'class': 'btn cbi-button cbi-button-apply', 'click': ui.createHandlerFn(this, 'startUpdate', st) }, _('Update now'))
					: E('em', st.latest ? _('Up to date.') : '')
			])
		]);

		m = new form.Map('ppe-update');
		s = m.section(form.NamedSection, 'main', 'ppe-update', _('Automatic update'));
		o = s.option(form.Flag, 'auto', _('Update automatically'),
			_('Checks once a day and installs a newer release, keeping settings and added packages.'));
		o.rmempty = false;
		o = s.option(form.ListValue, 'hour', _('Hour of the check'));
		for (var h = 0; h < 24; h++)
			o.value(String(h), '%02d:00'.format(h));
		o.default = '4';
		o.depends('auto', '1');
		o = s.option(form.Value, 'delay', _('Wait this many days after a release'),
			_('A release is installed only after it has been out this long.'));
		o.datatype = 'uinteger';
		o.default = '1';
		o.depends('auto', '1');

		return m.render().then(function(node) {
			return E([], [ status, node ]);
		});
	}
});
