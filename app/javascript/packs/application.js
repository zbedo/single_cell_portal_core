/* eslint no-console:0 */
/*
 * This file is automatically compiled by Webpack, along with any other files
 * present in this directory. You're encouraged to place your actual
 * application logic in a relevant structure within app/javascript and only
 * use these pack files to reference that code so it'll be compiled.
 *
 * To reference this file, add <%= javascript_pack_tag 'application' %> to
 * the appropriate layout file, like app/views/layouts/application.html.erb
 */

import 'styles/application.scss'

import React from 'react'
import ReactDOM from 'react-dom'
import $ from 'jquery'
import jQuery from 'jquery'
import { Spinner } from 'spin.js'
import 'jquery-ui/ui/widgets/datepicker'
import 'jquery-ui/ui/widgets/autocomplete'
import 'jquery-ui/ui/widgets/sortable'
import 'jquery-ui/ui/widgets/dialog'
import 'jquery-ui/ui/effects/effect-highlight'
import igv from 'igv'
import morpheus from 'morpheus-app'
import Ideogram from 'ideogram'
// Per https://ckeditor.com/docs/ckeditor5/latest/builds/guides/integration/advanced-setup.html#scenario-1-integrating-existing-builds
import ClassicEditor from '@ckeditor/ckeditor5-build-classic'


// Below import resolves to '/app/javascript/components/HomePageContent.js'
import HomePageContent from 'components/HomePageContent'
import Covid19PageContent from 'components/covid19/Covid19PageContent'
import { logPageView, logClick } from 'lib/metrics-api'

document.addEventListener('DOMContentLoaded', () => {
  if (document.getElementById('home-page-content')) {
    // Logs only page views for faceted search UI
    //
    // If/when Mixpanel is extended beyond home page, remove study name from
    // appPath in metrics-api.js at least for non-public studies to align with
    // Terra on identifiable data that we want to omit from this logging.
    logPageView()

    ReactDOM.render(
      <HomePageContent />, document.getElementById('home-page-content')
    )

    // Only logs clicks for home page with faceted search UI
    $(document).on('click', 'body', event => {
      logClick(event)
    })
  }
  if (document.getElementById('covid19-page-content')) {
    logPageView({ preset: 'covid19' })

    ReactDOM.render(
      <Covid19PageContent />, document.getElementById('covid19-page-content')
    )

    // Only logs clicks for home page with faceted search UI
    $(document).on('click', 'body', event => {
      logClick(event, { preset: 'covid19' })
    })
  }
})

// SCP expects these variables to be global.
window.$ = $
window.jQuery = jQuery
window.ClassicEditor = ClassicEditor
window.Spinner = Spinner
window.morpheus = morpheus
window.igv = igv
window.Ideogram = Ideogram

/*
 * For down the road, when we use ES6 imports in SCP JS app code
 * export {$, jQuery, ClassicEditor, Spinner, morpheus, igv, Ideogram};
 */
