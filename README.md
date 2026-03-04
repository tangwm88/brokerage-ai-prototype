# 机构经纪智能体 - 移动端原型

## 在线访问（临时链接）
https://develops-implies-row-documentary.trycloudflare.com/mobile_ui_effects.html

## 本地查看方法

### 方法1：直接用浏览器打开
1. 下载 `mobile_ui_effects.html` 文件
2. 双击用浏览器打开
3. 按 F12 → 点击手机图标切换到移动端视图

### 方法2：启动本地服务器
```bash
# 在文件所在目录运行
python3 -m http.server 8080

# 然后访问
http://localhost:8080/mobile_ui_effects.html
```

## 部署到永久托管

### 方案A：GitHub Pages（推荐）
1. 创建 GitHub 账号
2. 新建仓库，上传 HTML 文件
3. 开启 GitHub Pages 功能
4. 获得 `https://你的用户名.github.io/仓库名` 永久链接

### 方案B：Netlify Drop（最简单）
1. 访问 https://app.netlify.com/drop
2. 直接将 HTML 文件拖入页面
3. 立即获得永久链接

### 方案C：Vercel
1. 安装 Vercel CLI: `npm i -g vercel`
2. 在项目目录运行: `vercel`
3. 自动部署并获得永久链接

## 文件说明

| 文件 | 大小 | 说明 |
|------|------|------|
| mobile_ui_effects.html | 77KB | 完整UI效果版（推荐） |
| mobile_complete.html | 39KB | 基础完整版 |
| mobile_cards.html | 17KB | 卡片布局版 |
| institutional_brokerage_v2.html | 35KB | PC三栏版 |

所有文件位置：`/root/.openclaw/workspace/prototype/`
