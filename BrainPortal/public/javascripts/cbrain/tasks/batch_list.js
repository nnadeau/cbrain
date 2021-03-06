
/*
#
# CBRAIN Project
#
# Copyright (C) 2008-2012
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
*/

$(function () {
  "use strict";

  var icons = {
    batch_show: "ui-icon-plus",
    batch_hide: "ui-icon-minus",
    batch_load: "ui-icon-transfer-e-w"
  };

  /* Fetch the task list for batch row +row+ from +url+ */
  function fetch_batch(row, url) {
    $.get(url, function (data) {
      var rows   = $(data),
          batch  = rows.filter('.batch'),
          tasks  = rows.filter('.task');

      /* Replace the old row with the new ones */
      row
        .after(tasks)
        .replaceWith(batch);

      /* Add a few attributes to make expanding/collapsing tasks easier */
      batch
        .find('.batch-btn')
        .data('batch-type', 'loaded');

      tasks
        .addClass('batch-' + batch.data('batch-id'));

      /* The batch's checkbox should no longer send anything */
      batch
        .find('.dt-sel-check')
        .removeAttr('value')
        .removeAttr('name');

      /* Notify the table that its content changed */
      $('#tasks_table').trigger('refresh.dyn-tbl');
    });
  };

  $(document).delegate('#tasks_table, #tasks_display', 'new_content.batch_list', function () {
    var table = $('#tasks_display');

    /* Redirect clicks on the batch's type to the expand button */
    table
      .undelegate('tr.batch > td.type', 'click.batch_list')
      .delegate('tr.batch > td.type', 'click.batch_list', function (event) {
        event.stopPropagation();

        $(this).parent().find('.batch-btn').click();
      });

    /* Make the batch's checkbox select/deselect all tasks in the batch */
    table
      .undelegate('tr.batch > .dt-sel > .dt-sel-check', 'change.batch_list')
      .delegate('tr.batch > .dt-sel > .dt-sel-check', 'change.batch_list', function () {
        var checkbox = $(this);

        table
          .find('.task.batch-' + checkbox.closest('tr.batch').data('batch-id'))
          .find('.dt-sel-check')
          .prop('checked', checkbox.prop('checked'))
          .trigger('change');
      });

    /* Expand/fetch/open batch */
    table
      .undelegate('.batch-btn', 'click.batch_list')
      .delegate('.batch-btn', 'click.batch_list', function () {
        var button = $(this),
            type   = button.data('batch-type'),
            url    = button.data('batch-url');

        switch (type) {
        /* Direct link to the batch */
        case 'html_link':
          window.location.href = url;
          break;

        /* AJAX batch fetch */
        case 'ajax_fetch':
          button
            .data('batch-type', 'loading')
            .removeClass([ icons.batch_show, icons.batch_hide ].join(' '))
            .addClass(icons.batch_load);

          fetch_batch(button.closest('tr.batch'), url);

          break;

        /* Batch already loaded, just expand/collapse it */
        case 'loaded':
          button
            .toggleClass(icons.batch_show)
            .toggleClass(icons.batch_hide);

          table
            .find('.task.batch-' + button.closest('tr.batch').data('batch-id'))
            .toggle();

          break;

        /* Batch loading in progress, nothing to do */
        case 'loading':
        default:
          break;
        }
      });
  });

  $('#tasks_table').trigger('new_content.batch_list');
});
