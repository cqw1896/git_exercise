#!/bin/bash
# --------------------------------------------------------------
# pyenv 用户专属 · Vim 终极开发环境一键部署（完整修正版）
# 修正：检测 vim‑plug 和 YCM 编译状态，避免重复操作
# --------------------------------------------------------------
set -e

# ----------------------------------------------------------
# 检测函数：判断 vim‑plug 是否已安装
# ----------------------------------------------------------
check_vimplug_installed() {
    if [ -f "$HOME/.vim/autoload/plug.vim" ]; then
        echo ">>> 检测到 vim‑plug 已安装: $HOME/.vim/autoload/plug.vim"
        return 0
    else
        return 1
    fi
}

# ----------------------------------------------------------
# 检测函数：判断 YCM 是否已编译（使用正确的文件名模式）
# ----------------------------------------------------------
check_ycm_compiled() {
    local YCM_DIR="$HOME/.vim/plugged/YouCompleteMe"
    
    if [ ! -d "$YCM_DIR" ]; then
        return 1  # 目录不存在
    fi
    
    # 查找任何包含 "ycm_core" 的 .so 文件（支持不同Python版本的后缀）
    if find "$YCM_DIR" -name "*ycm_core*.so" | grep -q .; then
        local ycm_core_file=$(find "$YCM_DIR" -name "*ycm_core*.so" | head -1)
        echo ">>> 检测到 YCM 编译产物: $ycm_core_file"
        return 0  # 找到编译文件
    fi
    
    # 另外检查是否有编译目录
    if [ -d "$YCM_DIR/ycm_build" ] && [ "$(ls -A "$YCM_DIR/ycm_build" 2>/dev/null)" ]; then
        echo ">>> 检测到编译目录: $YCM_DIR/ycm_build"
        return 0
    fi
    
    return 1  # 未找到编译文件
}

# ----------------------------------------------------------
# 环境检查 & pyenv 自动安装
# ----------------------------------------------------------
PYENV_ROOT="$HOME/.pyenv"
BASHRC="$HOME/.bashrc"
PROFILE="$HOME/.profile"

if ! command -v apt >/dev/null 2>&1; then
    echo "❌ 本脚本仅支持基于 apt 的 Debian/Ubuntu 系统。"
    exit 1
fi

if ! command -v pyenv >/dev/null 2>&1 || [ ! -d "$PYENV_ROOT" ]; then
    echo "⚠️ 未检测到 pyenv，开始自动安装..."
    sudo apt update -qq
    sudo apt install -y make build-essential libssl-dev zlib1g-dev \
        libbz2-dev libreadline-dev libsqlite3-dev curl git \
        libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev \
        libffi-dev liblzma-dev
    set -o pipefail
    curl -fsSL https://pyenv.run | bash
    set +o pipefail
    PYENV_CFG=$(cat <<'EOF'
# --- pyenv Configuration Start ---
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - bash)"
# --- pyenv Configuration End ---
EOF
)
    grep -qxF 'export PYENV_ROOT="$HOME/.pyenv"' "$BASHRC" || echo "$PYENV_CFG" >> "$BASHRC"
    grep -qxF 'export PYENV_ROOT="$HOME/.pyenv"' "$PROFILE" || echo "$PYENV_CFG" >> "$PROFILE"
    source "$BASHRC" 2>/dev/null || source "$PROFILE"
    if ! command -v pyenv >/dev/null 2>&1; then
        echo "❌ pyenv 自动安装后仍无法使用，请手动检查。"
        exit 1
    fi
fi

export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# 检测 Python & pip
PYTHON=$(pyenv which python3 2>/dev/null)
if [ -z "$PYTHON" ]; then
    echo "❌ pyenv 未找到 python3，请先安装并设置为全局版本："
    echo "    pyenv install 3.x.x"
    echo "    pyenv global 3.x.x"
    pyenv versions
    exit 1
fi
PIP=$(dirname "$PYTHON")/pip
echo ">>> 检测到 Python : $PYTHON"
echo ">>> 检测到 pip    : $PIP"

# ----------------------------------------------------------
# 1️⃣ 系统依赖
# ----------------------------------------------------------
echo ">>> 安装系统依赖..."
sudo apt install -y vim git cmake clang libclang-dev curl python3-dev

# ----------------------------------------------------------
# 2️⃣ 检测 & 安装 vim‑plug
# ----------------------------------------------------------
echo ">>> 检查 vim‑plug 状态..."
if check_vimplug_installed; then
    echo "✅ 跳过 vim‑plug 安装（已存在）"
    VIMPLUG_NEEDS_INSTALL=false
else
    echo ">>> 安装 vim‑plug..."
    curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    VIMPLUG_NEEDS_INSTALL=true
fi

# ----------------------------------------------------------
# 3️⃣ 检测 YCM 编译状态（使用正确的文件名模式）
# ----------------------------------------------------------
YCM_DIR="$HOME/.vim/plugged/YouCompleteMe"
echo ">>> 检查 YCM 编译状态..."
echo ">>> 检查目录: $YCM_DIR"

if check_ycm_compiled; then
    echo "✅ YCM 已编译，跳过编译步骤"
    YCM_NEEDS_COMPILE=false
else
    echo "⚠️ YCM 未编译，需要编译"
    YCM_NEEDS_COMPILE=true
fi

# ----------------------------------------------------------
# 4️⃣ 生成 .vimrc
# ----------------------------------------------------------
echo ">>> 写入 .vimrc 配置..."

cat > ~/.vimrc <<'EOF'
" ======== .vimrc =========
" 基础设置
set number hidden updatetime=300 shortmess+=c
set completeopt-=preview
autocmd FileType python setlocal ts=4 sw=4 sts=4 expandtab

" 插件列表
call plug#begin('~/.vim/plugged')
Plug 'ycm-core/YouCompleteMe', {'do': 'git submodule update --init --recursive'}
Plug 'plasticboy/vim-markdown'
Plug 'terryma/vim-multiple-cursors'
Plug 'ambv/black'
Plug 'voldikss/vim-translator'
call plug#end()

" YCM 配置
let g:ycm_global_ycm_extra_conf = '~/.vim/.ycm_extra_conf.py'
let g:ycm_confirm_extra_conf = 0
let g:ycm_min_num_of_chars_for_completion = 2
let g:ycm_key_invoke_completion = '<M-;>'
let g:ycm_key_list_select_completion = ['<TAB>', '<Down>']
let g:ycm_key_list_previous_completion = ['<S-TAB>', '<Up>']
nnoremap <M-]> :YcmCompleter GoToDefinitionElseDeclaration<CR>

" Black 配置
let g:black_virtualenv = '~/.venv'
let g:black_linelength = 88
let g:black_fast = 1
autocmd BufWritePre *.py Black

" 快捷键
nnoremap <silent> rr :w<CR>:Black<CR>:!python3 "%:p"<CR>
inoremap jk <Esc>
smap    jk <Esc>
inoremap <M-h> <Left>
inoremap <M-j> <Down>
inoremap <M-k> <Up>
inoremap <M-l> <Right>

" 翻译功能（Ctrl+T）
let g:translator_default_engines = ['google']
let g:translator_window_type = 'popup'
let g:translator_window_borderchars = ['─','│','─','│','┌','┐','┘','└']

" 修改 .vimrc 中的翻译函数
function! AutoTranslate()
    let word = expand('<cword>')
    let word_trimmed = substitute(word, '^\s*\(.*\)\s*$', '\1', '')
    
    " 判断是否为中文（使用更准确的检测）
    if word_trimmed =~ '^[一-鿿]*$' && len(word_trimmed) > 0
        " 如果是中文，翻译成英文
        let g:translator_target_lang = 'en'
        " echo "🔄 翻译中文 → 英文: " . word_trimmed
    else
        " 如果不是中文，翻译成中文
        let g:translator_target_lang = 'zh-CN'
        " echo "🔄 翻译非中文 → 中文: " . word_trimmed
    endif
    Translate
endfunction


nnoremap <silent> <C-t> :call AutoTranslate()<CR>
vnoremap <silent> <C-t> :<C-u>call AutoTranslate()<CR>
inoremap <silent> <C-t> <Esc>:call AutoTranslate()<CR>a
" =================== .vimrc End ===================
EOF

# ----------------------------------------------------------
# 5️⃣ 为 Black 创建独立虚拟环境
# ----------------------------------------------------------
echo ">>> 配置 Black 专用虚拟环境..."
if [ ! -d "$HOME/.venv" ]; then
    "$PYTHON" -m venv ~/.venv
fi
(
    source ~/.venv/bin/activate
    pip install black
)

# ----------------------------------------------------------
# 6️⃣ 安装插件
# ----------------------------------------------------------
echo ">>> 自动安装 Vim 插件..."
vim -c 'PlugInstall!' -c 'qa'

# ----------------------------------------------------------
# 7️⃣ 条件性编译 YCM
# ----------------------------------------------------------
if [ "$YCM_NEEDS_COMPILE" = true ]; then
    echo ">>> 开始编译 YCM..."
    
    if [ ! -d "$YCM_DIR" ]; then
        echo "❌ YCM 插件目录不存在，请检查 PlugInstall 是否成功。"
        exit 1
    fi

    cd "$YCM_DIR" || exit 1

    # 确保子模块已初始化
    if [ ! -d "third_party/ycmd" ]; then
        echo ">>> 正在初始化/更新 YCM 子模块..."
        git submodule update --init --recursive
    fi

    # 编译
    BUILD_ROOT="$HOME/ycm-build-$$"
    "$PYTHON" -m venv "$BUILD_ROOT"
    (
        source "$BUILD_ROOT/bin/activate"
        pip install -U pip setuptools wheel
        python3 ./install.py --clangd-completer --build-dir="$BUILD_ROOT"
    )
    rm -rf "$BUILD_ROOT"
    
    # 再次检查编译结果（使用修正后的检测逻辑）
    echo ">>> 验证编译结果..."
    if check_ycm_compiled; then
        echo "✅ YCM 编译完成"
    else
        echo "❌ YCM 编译失败，请检查错误日志"
        exit 1
    fi
else
    echo ">>> 跳过 YCM 编译（已编译）"
fi

# ----------------------------------------------------------
# 8️⃣ 收尾 & 使用说明
# ----------------------------------------------------------
echo "------------------------------------------------"
echo "✅ 部署完成！"
echo ""
echo "📊 状态摘要："
echo " • pyenv     : $(command -v pyenv >/dev/null 2>&1 && echo "✅ 已安装" || echo "❌ 未安装")"
echo " • vim‑plug  : $([ -f "$HOME/.vim/autoload/plug.vim" ] && echo "✅ 已安装" || echo "❌ 未安装")"
echo " • YCM       : $(check_ycm_compiled && echo "✅ 已编译" || echo "❌ 未编译")"
echo " • Black     : ✅ 独立虚拟环境 ~/.venv"
echo ""
echo "📖 常用快捷键："
echo " • rr      : 保存 → Black 格式化 → 运行当前 .py"
echo " • Ctrl+T  : 光标单词的中英互译（Google 翻译）"
echo " • M-]     : 跳转到定义/声明（YCM）"
echo " • jk      : 快速从插入模式返回普通模式"
echo " • Alt+h/j/k/l : 在插入模式下移动光标"
echo "------------------------------------------------"
echo "🎉 祝你编码愉快！"
