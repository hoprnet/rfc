import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';
import remarkMath from 'remark-math';
import rehypeKatex from 'rehype-katex';

// This runs in Node.js - Don't use client-side code here (browser APIs, JSX...)


const config: Config = {
  title: 'HOPR RFCs',
  tagline: 'HOPR is cool, and decentralization is just the best',
  favicon: '/img/hopr_icon.svg',

  // Set the production url of your site here
  url: 'https://rfc.hoprnet.org',
  // Set the /<baseUrl>/ pathname under which your site is served
  // For GitHub pages deployment, it is often '/<projectName>/'
  baseUrl: '/',

  organizationName: 'HOPR',
  projectName: 'hoprnet',

  onBrokenLinks: 'throw',
  onBrokenMarkdownLinks: 'warn',
  

  // Even if you don't use internationalization, you can use this field to set
  // useful metadata like html lang. For example, if your site is Chinese, you
  // may want to replace "en" with "zh-Hans".
  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      {
        docs: {
          sidebarPath: './sidebars.ts',
          editUrl: 'https://github.com/hoprnet/rfc/ui',
          path: '../rfcs',
          routeBasePath: '/',
          // *** Ketex START ***
          remarkPlugins: [remarkMath],
          rehypePlugins: [rehypeKatex],
          // *** Ketex END ***
        },
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    // Replace with your project's social card
    image: 'img/hopr_icon.svg',
    colorMode: {
      defaultMode: 'dark',
      disableSwitch: true,
      respectPrefersColorScheme: false,
    },
    navbar: {
      title: 'HOPR RFCs',
      logo: {
        alt: 'HOPR Logo',
        src: 'img/hopr_icon.svg',
      },
      items: [
        {
          type: 'docSidebar',
          sidebarId: 'tutorialSidebar',
          position: 'left',
          label: 'Current Version',
        },
      //  {to: '/blog', label: 'Blog', position: 'left'},
        {
          href: 'https://github.com/hoprnet/rfc',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Docs',
          items: [
            {
              label: 'HOPR Docs',
              href: 'https://docs.hoprnet.org/',
            },
          ],
        },
        {
          title: 'Community',
          items: [
            {
              label: 'Telegram',
              href: 'https://t.me/hoprnet',
            },
            {
              label: 'Discord',
              href: 'https://discord.com/invite/dEAWC4G',
            },
            {
              label: 'X',
              href: 'https://x.com/hoprnet',
            },
          ],
        },
      ],
      copyright: `Copyright © ${new Date().getFullYear()} HOPR. Built with Docusaurus`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
    },
    tableOfContents: {
      minHeadingLevel: 2,
      maxHeadingLevel: 5,
    },

    // *** mermaid START ***
    mermaid: {
      options: {
        maxTextSize: 9999999,
      },
    },
    // *** mermaid END ***
  } satisfies Preset.ThemeConfig,

  // *** Ketex START ***
  stylesheets: [
    {
      href: 'https://cdn.jsdelivr.net/npm/katex@0.13.24/dist/katex.min.css',
      type: 'text/css',
      integrity:
        'sha384-odtC+0UGzzFL/6PNoE8rX/SPcQDXBJ+uRepguP4QkPCm2LBxH3FA3y+fKSiJ+AmM',
      crossorigin: 'anonymous',
    },
  ],
  // *** Ketex END ***

  // *** mermaid START ***
  markdown: {
    mermaid: true,
  },
  themes: ['@docusaurus/theme-mermaid'],
  // *** mermaid END ***
};

export default config;
