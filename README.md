# AlignTextProject

***使用word2vec对齐语音与文本，用于语音识别模型训练***

### 1.用法：
- perl FindBestTextFromSRTWithASR.pl input threadnum 

### 2.输入：
- a.使用vadnn切割后的input文件；
- b.nuance识别结果及存储index设置，详细见config/config.ini；
- c.并发线程数；

### 3.输出：
- a.实时输出到elasticSearch
