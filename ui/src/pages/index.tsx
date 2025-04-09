import type {ReactNode} from 'react';
import clsx from 'clsx';
import Link from '@docusaurus/Link';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import Layout from '@theme/Layout';

import Heading from '@theme/Heading';

import styles from './index.module.css';

function HomepageHeader() {
  const { siteConfig } = useDocusaurusContext();
  return (
    <header className={clsx('hero hero--primary', styles.heroBanner)}>
      <div className="container">
        <img
          src="./img/HOPR_logo.svg"
          style={{maxWidth: '1000px', width: '100%'}}
        />
        <Heading as="h1" className="hero__title">
          RFCs
        </Heading>
        <p className="hero__subtitle">{siteConfig.tagline}</p>
        <div className={styles.buttons}>
        <button
          style={{
            height: "30px",
            minHeight: "42px",
            fontSize: "20px",
            padding: "8px",
            background: "#050277",
          }}
          onClick={()=>{
            window.location.href = '/intro';
          }}
        >
          Click here to see the awesome RFCs
        </button>
        </div>
      </div>
    </header>
  );
}

export default function Home(): ReactNode {
  const { siteConfig } = useDocusaurusContext();
  return (
    <Layout
      title={`${siteConfig.title}`}
      description={`Request for Comments (RFC) for HOPR protocol`}>
      <HomepageHeader />
    </Layout>
  );
}
