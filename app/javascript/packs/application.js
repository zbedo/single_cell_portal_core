/* eslint no-console:0 */
// This file is automatically compiled by Webpack, along with any other files
// present in this directory. You're encouraged to place your actual application logic in
// a relevant structure within app/javascript and only use these pack files to reference
// that code so it'll be compiled.
//
// To reference this file, add <%= javascript_pack_tag 'application' %> to the appropriate
// layout file, like app/views/layouts/application.html.erb

import Ideogram from 'ideogram';
import $ from 'jquery';
import jQuery from 'jquery';

console.log('Hello World from Webpacker');

console.log('Ideogram.version:');
console.log(Ideogram.version);

window.$ = $;
window.jQuery = jQuery;

console.log('$')
console.log($)

console.log('jQuery')
console.log(jQuery)

export {$, jQuery, Ideogram};