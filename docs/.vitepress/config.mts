import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'Crecto Documentation',
  description: 'A Crystal ORM',
  base: '/crecto/',
  ignoreDeadLinks: true,
  themeConfig: {
    nav: [
      { text: 'Home', link: '/' },
      { text: 'Getting Started', link: '/guide' },
      { text: 'Core Concepts', link: '/core-concepts' },
      { text: 'Features', link: '/features-guide' },
      { text: 'Advanced', link: '/advanced-patterns' },
      { text: 'Examples', link: '/examples' },
      { text: 'API Reference', link: '/api-reference' }
    ],

    sidebar: [
      {
        text: 'Getting Started',
        items: [
          { text: 'Introduction', link: '/guide' },
          { text: 'Installation', link: '/guide#installation' },
          { text: 'Configuration', link: '/configuration' },
          { text: 'Quick Start', link: '/guide#quick-start-tutorial' }
        ]
      },
      {
        text: 'Core Concepts',
        items: [
          { text: 'Repository Pattern', link: '/core-concepts#repository-pattern' },
          { text: 'Model System', link: '/core-concepts#model-system' },
          { text: 'Changeset Pattern', link: '/core-concepts#changeset-pattern' },
          { text: 'Query System', link: '/core-concepts#query-system' },
          { text: 'Adapter System', link: '/core-concepts#adapter-system' }
        ]
      },
      {
        text: 'Features Guide',
        items: [
          { text: 'Schema Definition', link: '/features-guide#schema-definition' },
          { text: 'CRUD Operations', link: '/features-guide#crud-operations' },
          { text: 'Data Validation', link: '/features-guide#data-validation' },
          { text: 'Associations', link: '/features-guide#associations' },
          { text: 'Query Building', link: '/features-guide#query-building' }
        ]
      },
      {
        text: 'Advanced Usage',
        items: [
          { text: 'Transaction Management', link: '/advanced-patterns#transaction-management' },
          { text: 'Bulk Operations', link: '/advanced-patterns#bulk-operations' },
          { text: 'Performance Optimization', link: '/advanced-patterns#performance-optimization' },
          { text: 'Error Handling', link: '/advanced-patterns#error-handling-and-resilience' },
          { text: 'Testing Strategies', link: '/advanced-patterns#testing-strategies' }
        ]
      },
      {
        text: 'Examples & Tutorials',
        items: [
          { text: 'Complete Blog Application', link: '/examples#complete-application-example' },
          { text: 'User Management', link: '/examples#user-management' },
          { text: 'Blog Post Management', link: '/examples#blog-post-management' },
          { text: 'Advanced Queries', link: '/examples#advanced-query-examples' },
          { text: 'Bulk Operations', link: '/examples#bulk-operations' },
          { text: 'Transaction Examples', link: '/examples#transaction-examples' },
          { text: 'Performance Optimization', link: '/examples#performance-optimization-examples' },
          { text: 'Testing Examples', link: '/examples#testing-examples' }
        ]
      },
      {
        text: 'API Reference',
        items: [
          { text: 'Crecto::Repo', link: '/api-reference#crectorepo' },
          { text: 'Crecto::Model', link: '/api-reference#crectomodel' },
          { text: 'Crecto::Changeset', link: '/api-reference#crectochangeset' },
          { text: 'Crecto::Query', link: '/api-reference#crectoquery' },
          { text: 'Associations', link: '/api-reference#associations' },
          { text: 'Adapters', link: '/api-reference#adapters' },
          { text: 'Error Types', link: '/api-reference#error-types' }
        ]
      }
    ],

    socialLinks: [
      { icon: 'github', link: 'https://github.com/Crecto/Crecto' }
    ]
  }
})