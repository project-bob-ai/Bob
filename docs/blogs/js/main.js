/**
 * Bob IBM i Blogs — main.js
 * Shared utility scripts for the blog site.
 */

// Highlight the active nav link based on current URL
document.addEventListener('DOMContentLoaded', function () {
  const links = document.querySelectorAll('nav a');
  links.forEach(function (link) {
    if (link.href === window.location.href) {
      link.setAttribute('aria-current', 'page');
      link.style.borderBottom = '2px solid #0f62fe';
    }
  });
});
