#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: $(basename "$0") [--force]

Creates a Clean Architecture-ready folder structure for a Flutter project with
Data, Domain, and Presentation layers plus supporting core utilities. Run this
from the root of a Flutter project (where pubspec.yaml lives).

Options:
  --force   Recreate folders and template files even if they already exist.
USAGE
}

if [[ ${1:-""} == "-h" || ${1:-""} == "--help" ]]; then
  usage
  exit 0
fi

FORCE=false
if [[ ${1:-""} == "--force" ]]; then
  FORCE=true
fi

if [[ ! -f "pubspec.yaml" ]]; then
  echo "Error: pubspec.yaml not found. Run this command from your Flutter project root." >&2
  exit 1
fi

create_dir() {
  local dir="$1"
  if [[ -d "$dir" && $FORCE == false ]]; then
    echo "skip  $dir (already exists)"
  else
    mkdir -p "$dir"
    echo "create $dir"
  fi
}

write_file() {
  local file="$1"
  shift
  if [[ -f "$file" && $FORCE == false ]]; then
    echo "skip  $file (already exists)"
    return
  fi
  cat > "$file"
  echo "write  $file"
}

create_dir "lib/src/core/config"
create_dir "lib/src/core/error"
create_dir "lib/src/core/network"
create_dir "lib/src/core/usecase"
create_dir "lib/src/core/utils"

create_dir "lib/src/data/datasources"
create_dir "lib/src/data/models"
create_dir "lib/src/data/repositories"

create_dir "lib/src/domain/entities"
create_dir "lib/src/domain/repositories"
create_dir "lib/src/domain/usecases"

create_dir "lib/src/presentation/cubit"
create_dir "lib/src/presentation/pages"
create_dir "lib/src/presentation/widgets"

create_dir "lib/src/services"
create_dir "test/src"

write_file "lib/src/core/config/app_environment.dart" <<'EOF'
/// Describes the active app environment (dev, staging, production).
class AppEnvironment {
  AppEnvironment({required this.name, required this.baseUrl});

  final String name;
  final String baseUrl;
}
EOF

write_file "lib/src/core/error/failure.dart" <<'EOF'
/// Base class for failures returned by use cases.
abstract class Failure {
  const Failure([this.message = 'An unexpected error occurred.']);

  final String message;
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message]);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message]);
}
EOF

write_file "lib/src/core/usecase/usecase.dart" <<'EOF'
import 'package:dartz/dartz.dart';

import '../error/failure.dart';

/// Generic interface for application use cases.
abstract class UseCase<Type, Params> {
  Future<Either<Failure, Type>> call(Params params);
}

class NoParams {
  const NoParams();
}
EOF

write_file "lib/src/data/repositories/example_repository_impl.dart" <<'EOF'
import 'package:dartz/dartz.dart';

import '../../core/error/failure.dart';
import '../../domain/entities/example_entity.dart';
import '../../domain/repositories/example_repository.dart';

class ExampleRepositoryImpl implements ExampleRepository {
  @override
  Future<Either<Failure, ExampleEntity>> fetchExample() async {
    // TODO(amgbeigi): implement datasource call
    return const Right(
      ExampleEntity(id: 'example', value: 'Hello, Clean Architecture!'),
    );
  }
}
EOF

write_file "lib/src/domain/entities/example_entity.dart" <<'EOF'
class ExampleEntity {
  const ExampleEntity({required this.id, required this.value});

  final String id;
  final String value;
}
EOF

write_file "lib/src/domain/repositories/example_repository.dart" <<'EOF'
import 'package:dartz/dartz.dart';

import '../../core/error/failure.dart';
import '../entities/example_entity.dart';

abstract class ExampleRepository {
  Future<Either<Failure, ExampleEntity>> fetchExample();
}
EOF

write_file "lib/src/domain/usecases/get_example.dart" <<'EOF'
import 'package:dartz/dartz.dart';

import '../../core/error/failure.dart';
import '../../core/usecase/usecase.dart';
import '../entities/example_entity.dart';
import '../repositories/example_repository.dart';

class GetExample extends UseCase<ExampleEntity, NoParams> {
  GetExample(this.repository);

  final ExampleRepository repository;

  @override
  Future<Either<Failure, ExampleEntity>> call(NoParams params) {
    return repository.fetchExample();
  }
}
EOF

write_file "lib/src/presentation/cubit/example_cubit.dart" <<'EOF'
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/usecase/usecase.dart';
import '../../domain/entities/example_entity.dart';
import '../../domain/usecases/get_example.dart';

part 'example_state.dart';

class ExampleCubit extends Cubit<ExampleState> {
  ExampleCubit(this._getExample) : super(const ExampleState.initial());

  final GetExample _getExample;

  Future<void> load() async {
    emit(const ExampleState.loading());
    final result = await _getExample(const NoParams());
    result.fold(
      (failure) => emit(ExampleState.failure(failure.message)),
      (entity) => emit(ExampleState.success(entity)),
    );
  }
}
EOF

write_file "lib/src/presentation/cubit/example_state.dart" <<'EOF'
part of 'example_cubit.dart';

class ExampleState {
  const ExampleState._({
    required this.status,
    this.entity,
    this.errorMessage,
  });

  const ExampleState.initial() : this._(status: ExampleStatus.initial);
  const ExampleState.loading() : this._(status: ExampleStatus.loading);
  const ExampleState.success(ExampleEntity entity)
      : this._(status: ExampleStatus.success, entity: entity);
  const ExampleState.failure(String message)
      : this._(status: ExampleStatus.failure, errorMessage: message);

  final ExampleStatus status;
  final ExampleEntity? entity;
  final String? errorMessage;
}

enum ExampleStatus { initial, loading, success, failure }
EOF

write_file "lib/src/presentation/pages/example_page.dart" <<'EOF'
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/get_example.dart';
import '../cubit/example_cubit.dart';

class ExamplePage extends StatelessWidget {
  const ExamplePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ExampleCubit(
        context.read<GetExample>(),
      )..load(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Clean Architecture Example')),
        body: BlocBuilder<ExampleCubit, ExampleState>(
          builder: (context, state) {
            switch (state.status) {
              case ExampleStatus.initial:
                return const SizedBox.shrink();
              case ExampleStatus.loading:
                return const Center(child: CircularProgressIndicator());
              case ExampleStatus.success:
                return Center(child: Text(state.entity!.value));
              case ExampleStatus.failure:
                return Center(child: Text(state.errorMessage ?? 'Error'));
            }
          },
        ),
      ),
    );
  }
}
EOF

write_file "lib/src/presentation/widgets/example_tile.dart" <<'EOF'
import 'package:flutter/material.dart';

import '../../domain/entities/example_entity.dart';

class ExampleTile extends StatelessWidget {
  const ExampleTile(this.entity, {super.key});

  final ExampleEntity entity;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(entity.value),
      subtitle: Text('id: ${entity.id}'),
    );
  }
}
EOF

write_file "test/src/example_cubit_test.dart" <<'EOF'
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// TODO: replace `project` with the package name defined in your pubspec.yaml.
import 'package:project/src/core/error/failure.dart';
import 'package:project/src/core/usecase/usecase.dart';
import 'package:project/src/domain/entities/example_entity.dart';
import 'package:project/src/domain/usecases/get_example.dart';
import 'package:project/src/presentation/cubit/example_cubit.dart';

class _MockGetExample extends Mock implements GetExample {}

void main() {
  late _MockGetExample getExample;
  late ExampleCubit cubit;

  setUp(() {
    getExample = _MockGetExample();
    cubit = ExampleCubit(getExample);
  });

  test('emits success when GetExample returns entity', () async {
    const entity = ExampleEntity(id: '1', value: 'test');
    when(() => getExample(const NoParams()))
        .thenAnswer((_) async => const Right(entity));

    await cubit.load();

    expect(cubit.state.status, ExampleStatus.success);
    expect(cubit.state.entity, entity);
  });

  test('emits failure when GetExample returns failure', () async {
    when(() => getExample(const NoParams()))
        .thenAnswer((_) async => const Left(NetworkFailure('no network')));

    await cubit.load();

    expect(cubit.state.status, ExampleStatus.failure);
    expect(cubit.state.errorMessage, 'no network');
  });
}
EOF

cat <<'NOTE'
Clean architecture structure ready.
Recommended pubspec additions (if not already present):
  flutter pub add dartz flutter_bloc equatable
  flutter pub add --dev mocktail flutter_test
NOTE
