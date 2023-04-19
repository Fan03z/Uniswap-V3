import "@/styles/globals.css";
import Head from "next/head";
import type { AppProps } from "next/app";
import { TransactionProvider } from "@/context/TransactionContext";

export default function App({ Component, pageProps }: AppProps) {
  return (
    <>
      <Head>
        <title>Uniswap V3</title>
      </Head>
      <TransactionProvider>
        <Component {...pageProps} />;
      </TransactionProvider>
    </>
  );
}
