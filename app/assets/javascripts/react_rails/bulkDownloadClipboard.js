/**
 * @fileoverview Code here is used in React components and JS in Rails templates
 * 
 * Benefit: reuse of traditional JavaScript in React components, DRY, faster implementation
 * Cost: Functionality related to this code can't be easily tested in our new Jest test framework.
 *
 * When the "Old use" is migrated to React, rewrite corresponding legacy JS here into React
 * then delete the legacy JS.
 *
 */

window.SCP = window.SCP || {

  // Old use: app/views/site/_study_download_data.html.erb
  // New use: app/javascript/components/DownloadButton.js
  initBulkDownloadClipboard: function() {
    // Enables copying to clipboard upon clicking a "clipboard" icon,
    // like on GitHub.  https://clipboardjs.com.
    var clipboard = new Clipboard('.btn-copy');
    clipboard.on('success', function(event) {
    $('#' + event.trigger.id)
      .attr('title', 'Copied!')
      .tooltip('fixTitle')
      .tooltip('show');
    });

    $('body').on('click', '.btn-refresh', function(event) {
      var commandContainer = $(this).parentsUntil('.command-container').parent();
      var downloadObject = commandContainer.attr('id').split('-').slice(-1)[0];
      writeDownloadCommand(downloadObject);
    });
    
  }

}
