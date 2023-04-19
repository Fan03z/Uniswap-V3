# Uniswap V3

Uniswap V3(后面简称 Uniswap)中的合约分为 **核心合约(core contracts)** 和 **外部合约(periphery contracts)**

核心合约包含:

1. 池子合约(Pool contracts), 实现去中心化交易逻辑
2. 工厂合约(Factory contracts),作为池子合约的注册入口,简化池子合约的部署

## NextJS --Frontend

## Sanity --Backend (CMS)

> > > > > > > main

操作步骤文档: <https://www.sanity.io/docs/getting-started-with-sanity?utm_source=readme>

参考文档: <https://www.sanity.io/docs/reference?utm_source=readme>

1. 先安装 sanity 库`yarn add @sanity/cli`;

2. 初始化 sanity 项目 --V3 版:`yarn create sanity`或者,--V2 版:`sanity init --coupon cleverprogrammer`,接着根据提示走就好了(@sanity V2 和 V3 创建初始化项目时会有点区别,但按着提示走就好了)

> **注意**: 如果是第一次全局安装 sanity 的话,可能要先加入全局环境变量 `export PATH="$(yarn global bin):$PATH"`;
>
> 如果是仅是项目本地安装 sanity 的话,可能也要加入本地项目环境变量`export PATH="./node_modules/.bin:$PATH"`

3. cd 到 sanity 项目目录,启动 sanity 项目:`yarn run dev`,然后就可以访问 <http://localhost:3333/>
