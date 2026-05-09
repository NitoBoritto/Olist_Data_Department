document.addEventListener('DOMContentLoaded', () => {
  const themeToggleCheckbox = document.getElementById('themeToggleCheckbox');
  
  // Default to dark theme as requested
  let currentTheme = localStorage.getItem('theme') || 'dark';
  
  const applyTheme = (theme) => {
    document.documentElement.setAttribute('data-theme', theme);
    if (themeToggleCheckbox) {
      themeToggleCheckbox.checked = theme === 'dark';
    }
  };
  
  // Apply the theme on load
  applyTheme(currentTheme);
  
  if (themeToggleCheckbox) {
    themeToggleCheckbox.addEventListener('change', (e) => {
      currentTheme = e.target.checked ? 'dark' : 'light';
      localStorage.setItem('theme', currentTheme);
      applyTheme(currentTheme);
    });
  }
});
