
import os
import pandas as pd
import streamlit as st
from langchain_community.vectorstores import Qdrant
from langchain_core.output_parsers import StrOutputParser
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.runnables import RunnablePassthrough
#from langchain_community.chat_models import ErnieBotChat
#from langchain_community.embeddings import ErnieEmbeddings
from langchain_community.document_loaders import PyPDFLoader,Docx2txtLoader,TextLoader
#from langchain.retrievers.multi_query import MultiQueryRetriever
from langchain_community.document_transformers import LongContextReorder
from langchain.text_splitter import RecursiveCharacterTextSplitter
import json
import re
from langchain_community.llms import Tongyi
from langchain_community.embeddings import DashScopeEmbeddings
import warnings
warnings.filterwarnings("ignore")

#-----------------------模型准备------------------------

# 读取API Key配置文件
with open('/Users/wangdan/Downloads/LangChain实战/data/api_config.json') as f:
    api_key = json.load(f)

# 模型密钥（有需要可以新增）
#ernie_client_id = api_key['API Key']         # 文心大模型ernie_client_id
#ernie_client_secret = api_key['Secret Key']  # 文心大模型ernie_client_secret
DASHSCOPE_API_KEY = api_key['DASHSCOPE_API_KEY'] # 阿里通义千问模型DASHSCOPE_API_KEY

# 大模型配置（有需要可以新增。记得安装对应的包、从langchain导入对应的模型）
#llm1 = ErnieBotChat(model_name='ERNIE-Bot-4',ernie_client_id=ernie_client_id,ernie_client_secret=ernie_client_secret,temperature=1,)
llm2 = Tongyi(temperature=1, dashscope_api_key=DASHSCOPE_API_KEY)
# llm3 = ...

# Embedding配置（有需要可以新增。记得安装对应的包、从langchain导入对应的ErnieEmbeddings模型）
#embedding1 = ErnieEmbeddings(ernie_client_id=ernie_client_id,ernie_client_secret=ernie_client_secret)
embedding2 = DashScopeEmbeddings(
    model="text-embedding-v2", dashscope_api_key=DASHSCOPE_API_KEY
)
# embedding3 = ...

# -----------------------数据读取、切分、向量化、问答等函数------------------------

def load_document(file):
    '''
    导入文档，支持 PDF, DOCX and TXT 文件
    :param file: 文件路径
    :return: 文本数据
    '''
    name, extension = os.path.splitext(file)
    if extension == '.pdf':
        loader = PyPDFLoader(file)
        documents = loader.load()
    elif extension == '.docx':
        loader = Docx2txtLoader(file)
        documents = loader.load()
    elif extension == '.txt':
        try:
            loader = TextLoader(file, encoding='utf8')
            documents = loader.load()
        except:
            loader = TextLoader(file, encoding='gbk')
            documents = loader.load()
    else:
        st.error('不支持的文件格式，仅支持PDF、DOCX、TXT文件')
        documents = ''
    # 文档预处理
    documents[0].page_content = re.sub(r'\n{2,}', '\n', documents[0].page_content)
    documents[0].page_content = re.sub(r'\t', '', documents[0].page_content)
    return documents


def create_embeddings(documents, embedding):
    '''
    文档向量化和存储
    :param documents: 切分好的文档
    :param embedding: 向量化模型
    :return: 向量化存储的对象
    '''
    vectorstore = Qdrant.from_documents(
        documents=documents,
        embedding=embedding,
        location=':memory:',
        collection_name='my_documents')
    return vectorstore


def chunk_data(data, file_name='a.txt', chunk_size=256, chunk_overlap=100):
    '''
    文档切分
    :param data: 待切分的文档
    :param file_name: 文件名
    :param chunk_size: 切块大小
    :param chunk_overlap: 切块重叠大小
    :return: 切分后的文档对象
    '''
    text_splitter = RecursiveCharacterTextSplitter(chunk_size=chunk_size, chunk_overlap=chunk_overlap)
    chunks = text_splitter.split_documents(data)
    file_name = file_name.split('.')[0] # 去除文件名后缀
    for i in chunks: # 给每个分块添加对于的来源文件名，便于检索更精确
        i.page_content = file_name+'。'+i.page_content
    return chunks


# 清空对话记录
def clear_chat_history():
    '''
    清空对话记录
    :return:
    '''
    if 'messages' in st.session_state:
        del st.session_state['messages']

def clear_embedding():
    '''
    清空知识库和文档
    :return:
    '''
    for i in st.session_state.filenames: # 删除保存的文件
        try:
            delfile = os.path.join('./', i)
            os.remove(delfile)
        except:
            pass
    st.session_state.vs = [] # 清空向量
    st.session_state.filenames = [] # 清空保存的文件名
    st.info('知识库已清空，可以新增知识库后继续。')
    global file_name
    try:
        del file_name # 删除文件名变量
    except:
        pass

def format_docs(docs):
    '''
    将返回的文档page_content的内容拼接为字符串，减少其他信息干扰
    :param docs: 文档对象
    :return: 拼接后的字符串
    '''
    reordering = LongContextReorder() # 实例化对象
    reordered_docs = reordering.transform_documents(docs) # 文档重排
    # 文档重排后，将内容拼接为字符串输出
    return "\n\n".join([doc.page_content for doc in reordered_docs])
    # return "\n\n".join(doc.page_content for doc in docs)

def ask_and_get_answer(llm, ask, vector_store, k=3):
    '''
    问答函数
    :param llm: 大模型
    :param ask: 问题
    :param vector_store: 向量化存储的对象
    :param k: 相似度前k个文档
    :return: 答案
    '''
    if st.session_state.vs != []: # 若添加了知识库，则根据知识库回答问题
        if k>3:
            retriever = vector_store.as_retriever(search_type='similarity', search_kwargs={'k': k})
        else:
            retriever = vector_store.as_retriever(search_type='similarity')
        retriever_from_llm = MultiQueryRetriever.from_llm(
            retriever=retriever, llm=llm
        )

        template = '''Answer the question based only on the following context:{context}
        Please answer the question only by chinese.
        If you can't answer the question, please say "对不起，我没有找到相关的知识".
        Question:{question}
        '''
        prompt = ChatPromptTemplate.from_template(template)
        output_parser = StrOutputParser()

        chain = {"context": retriever | format_docs, "question": RunnablePassthrough()} \
                | prompt \
                | llm \
                | output_parser
        output = chain.invoke(ask)
    else: # 若没添加知识库，则根据大模型本身的认知回答问题
        template = '''Answer the question by chinese.
        Question:{question}
        '''
        prompt = ChatPromptTemplate.from_template(template)
        chain = {"question": RunnablePassthrough()}| prompt | llm | StrOutputParser()
        output = chain.invoke(ask) + '\n\n（温馨提示：以上回答是基于通用数据的回答，若想基于文档回答请先【添加知识库】）'
    return output


def convert_df():
    '''
    将对话记录转换为csv文件
    :return:
    '''
    df = pd.DataFrame(st.session_state.messages)
    df = df.applymap(lambda x: str(x).replace('\n', '').replace(',', '，'))
    return df.to_csv(index=False, encoding='utf-8', mode='w', sep=',')

# -------------------------主页面设置------------------------

st.set_page_config(page_title='LLM Question-Answering App', page_icon=':robot:', layout='wide')
st.title('基于Langchain的文档检索（RAG） 🤖')
st.markdown('---')

# 初始化聊天记录
if "messages" not in st.session_state:
    st.session_state.messages = []

#  初始化知识库
if "vs" not in st.session_state:
    st.session_state.vs = []
#  初始化导入的文件名

if "filenames" not in st.session_state:
    st.session_state.filenames = []

if st.session_state.filenames == []:
    st.error(f"您还没有添加知识库，模型的回答将基于通用知识。")

# 展示聊天记录
for message in st.session_state.messages:
    if message["role"] == "user":
        with st.chat_message(message["role"], avatar='☺️'):
            st.markdown(message["content"])
    else:
        with st.chat_message(message["role"], avatar='🤖'):
            st.markdown(message["content"])


# ---------------------侧边栏设置-----------------------

# 文档上传
st.sidebar.subheader('上传知识库')
uploaded_file = st.sidebar.file_uploader('文件上传:', type=['pdf', 'docx', 'txt', 'doc'])

if uploaded_file is None:
    st.error('注意，先上传文件-配置知识库！')
    # st.stop()
else:
    st.sidebar.warning(f'上传成功！注意【添加知识库】')

# 分块参数
chunk_size = st.sidebar.number_input('分块大小:', min_value=100, max_value=2048, value=1024)
# 搜索文档参数
k = st.sidebar.number_input('搜索返回文档数（小于3则返回None）', min_value=1, max_value=100, value=10)
# 模型选择参数，若有需要可在列表 ['阿里通义千问', '百度千帆'] 中添加， 比如['阿里通义千问', '百度千帆', 'chatgpt']
myllm = st.sidebar.selectbox('模型选择', ['阿里通义千问', '百度千帆'])
# 根据选择的模型，添加对应的Embedding模型, 若有需要可在if...else...中添加
if myllm == '百度千帆':
    llm = llm1
    embedding = embedding1
elif myllm == '阿里通义千问':
    llm = llm2
    embedding = embedding2
else:
    pass

# 知识库管理参数
add_or_no = st.sidebar.radio('知识库管理', ['合并新增知识库', '仅使用当前知识库'])

# 点击导入文件后，将文件内容写入本地（是一个中间操作，方便后续使用pdf或txt等格式读取）
if uploaded_file:  # if the user browsed a file
    with st.spinner('正在读取文件 ...'):
        # streamlit框架读取文件对象
        bytes_data = uploaded_file.read()

        # 文件写出
        file_name = os.path.join('./', uploaded_file.name)
        with open(file_name, 'wb') as f:
            f.write(bytes_data)
        if add_or_no == '合并新增知识库':
            st.session_state.filenames.append(uploaded_file.name)
        else:
            st.session_state.filenames= [uploaded_file.name]

# ---------------------对话栏对话设置-----------------------

if prompt := st.chat_input('请输入你的问题'):
    # 输入问题
    with st.chat_message('user', avatar='☺️'):
        st.markdown(prompt)
    # 在历史对话中添加用户的问题
    st.session_state.messages.append({'role': 'user', 'content': prompt})
    # 调用函数，获取回答
    with st.spinner('正在检索，请稍后 ...'):
        response = ask_and_get_answer(llm, prompt, st.session_state.vs, k)
    # 输出答案
    with st.chat_message('AI', avatar='🤖'):
        st.markdown(response)
    # 在历史对话中添加问题的答案
    st.session_state.messages.append({'role': 'AI', 'content': response})


# ---------------------对话栏清空对话、导入知识库等设置-----------------------
col1, col2, col3, col4, _ = st.columns([1, 1,  1, 1, 1])

with col2:
    drop_embedding = st.button('清空知识库', use_container_width=True)
if drop_embedding:
    clear_embedding()
    st.toast(':red[知识库已清空！]', icon='🤖')

with col3:
    if st.button("清除对话历史", on_click=clear_chat_history, use_container_width = True):
        st.session_state["messages"] = []
        st.toast(':red[对话历史已清除！]', icon='🤖')

with col4:
    download_button = st.download_button(label="导出对话记录",
                                         data=convert_df(), # 导出函数
                                         file_name='chat_history.csv', # 文件名
                                         mime='text/csv',  # 文件类型
                                         use_container_width=True)

    # st.write(pd.DataFrame(st.session_state["messages"]))
    # download_button = st.download_button(label="导出对话记录",
    #                         data=json.dumps(st.session_state["messages"]),
    #                         file_name='chat_history.json',
    #                         mime='text/csv')


with col1:
    add = st.button('添加知识库', use_container_width=True)
if add:
    with st.spinner("知识库生成中..."):
        # 读取文档
        data = load_document(file_name)
        #  分割数据
        chunks = chunk_data(data,file_name=file_name, chunk_size=chunk_size)
        # 创建知识库的嵌入向量
        vector_store = create_embeddings(chunks, embedding)
        st.toast(':red[知识库添加成功！]', icon='🤖')
        # 保存知识库
        if add_or_no == '合并新增知识库':
            if st.session_state.vs==[]:
                st.session_state.vs = vector_store
            else:
                st.session_state.vs.add_documents(chunks) # 添加新的文档
        else:
            st.session_state.vs = vector_store
        # 添加知识库名称
        files = '；'.join(list(set(st.session_state.filenames)))
        st.success(f'添加成功！已有知识库：{files}')
        if st.session_state.messages == []:
            st.session_state.messages.append({'role': 'AI', 'content': f'已有知识库：{files}'})
        else:
            st.session_state.messages[-1] = {'role': 'AI', 'content': f'已有知识库：{files}'}
        with st.chat_message('AI', avatar='🤖'):
            st.markdown(st.session_state.messages[-1]['content'])



