import { useEffect } from 'react';
import type { ReactNode } from 'react';
import clsx from 'clsx';
import { useHistory } from '@docusaurus/router';
import * as Fathom from 'fathom-client';
import Button from '../components/Button';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import Layout from '@theme/Layout';
import Heading from '@theme/Heading';
import styles from './index.module.css';

function HomepageHeader() {
  const { siteConfig } = useDocusaurusContext();
  const history = useHistory();

  useEffect(() => {
    Fathom.load('MTQEWUCK', {
      url: 'https://cdn-eu.usefathom.com/script.js',
      spa: 'auto',
      excludedDomains: ['localhost:3000'],
    });
  }, []);
  
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
        <Button
          onClick={()=>{
            history.push('/intro');
          }}
        >
          Click here to see the awesome RFCs
        </Button>
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
      description={`Request for Comments (RFC) for HOPR protocol`}
    >
      <HomepageHeader />
    </Layout>
  );
}
