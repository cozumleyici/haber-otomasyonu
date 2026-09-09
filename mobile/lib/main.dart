import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/theme/app_theme.dart';
import 'repositories/news_repository.dart';
import 'bloc/pending_news/pending_news_bloc.dart';
import 'bloc/pending_news/pending_news_event.dart';
import 'bloc/review_action/review_action_bloc.dart';
import 'ui/screens/pending_news_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final newsRepository = NewsRepository();

  runApp(
    NewsPublisherApp(newsRepository: newsRepository),
  );
}

class NewsPublisherApp extends StatelessWidget {
  final NewsRepository newsRepository;

  const NewsPublisherApp({Key? key, required this.newsRepository}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<NewsRepository>.value(value: newsRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<PendingNewsBloc>(
            create: (context) => PendingNewsBloc(repository: newsRepository)
              ..add(const FetchPendingNews()),
          ),
          BlocProvider<ReviewActionBloc>(
            create: (context) => ReviewActionBloc(repository: newsRepository),
          ),
        ],
        child: MaterialApp(
          title: 'Haber Asistanı & Yayıncı',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.system,
          home: PendingNewsScreen(newsRepository: newsRepository),
        ),
      ),
    );
  }
}
