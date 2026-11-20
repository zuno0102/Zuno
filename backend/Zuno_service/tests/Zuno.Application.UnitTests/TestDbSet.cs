using System.Collections;
using System.Linq.Expressions;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Query;
using Moq;

namespace Zuno.Application.UnitTests;

/// <summary>
/// A <see cref="DbSet{T}"/> over a list, for handlers that query the context directly.
/// </summary>
/// <remarks>
/// A plain <c>Mock&lt;DbSet&lt;T&gt;&gt;</c> is not enough: <c>ToListAsync</c> and friends need an
/// async query provider, and without one a handler under test throws rather than returning
/// nothing. Small enough to keep here rather than take a dependency on a mocking package for it.
/// </remarks>
public static class TestDbSet
{
    public static DbSet<T> From<T>(params T[] items)
        where T : class =>
        Over(items.AsQueryable(), new Mock<DbSet<T>>());

    /// <summary>
    /// A set over <paramref name="rows"/> that also takes <c>Add</c>, <c>AddRange</c>, <c>Remove</c> and
    /// <c>RemoveRange</c>, so a test sees what a handler wrote by reading the list.
    /// </summary>
    public static DbSet<T> Over<T>(List<T> rows)
        where T : class
    {
        var mock = new Mock<DbSet<T>>();
        mock.Setup(m => m.Add(It.IsAny<T>())).Callback<T>(rows.Add);
        mock.Setup(m => m.AddRange(It.IsAny<IEnumerable<T>>())).Callback<IEnumerable<T>>(added => rows.AddRange(added.ToList()));
        mock.Setup(m => m.Remove(It.IsAny<T>())).Callback<T>(item => rows.Remove(item));
        mock.Setup(m => m.RemoveRange(It.IsAny<IEnumerable<T>>())).Callback<IEnumerable<T>>(removed =>
        {
            foreach (var item in removed.ToList())
            {
                rows.Remove(item);
            }
        });
        return Over(rows.AsQueryable(), mock);
    }

    private static DbSet<T> Over<T>(IQueryable<T> data, Mock<DbSet<T>> mock)
        where T : class
    {

        mock.As<IAsyncEnumerable<T>>()
            .Setup(m => m.GetAsyncEnumerator(It.IsAny<CancellationToken>()))
            .Returns((CancellationToken _) => new AsyncEnumerator<T>(data.GetEnumerator()));

        mock.As<IQueryable<T>>().Setup(m => m.Provider).Returns(new AsyncQueryProvider<T>(data.Provider));
        mock.As<IQueryable<T>>().Setup(m => m.Expression).Returns(data.Expression);
        mock.As<IQueryable<T>>().Setup(m => m.ElementType).Returns(data.ElementType);
        mock.As<IQueryable<T>>().Setup(m => m.GetEnumerator()).Returns(() => data.GetEnumerator());

        return mock.Object;
    }

    private sealed class AsyncQueryProvider<T>(IQueryProvider inner) : IAsyncQueryProvider
    {
        public IQueryable CreateQuery(Expression expression) => new AsyncQueryable<T>(expression, this);

        public IQueryable<TElement> CreateQuery<TElement>(Expression expression) =>
            new AsyncQueryable<TElement>(expression, this);

        public object? Execute(Expression expression) => inner.Execute(expression);

        public TResult Execute<TResult>(Expression expression) => inner.Execute<TResult>(expression);

        public TResult ExecuteAsync<TResult>(Expression expression, CancellationToken cancellationToken)
        {
            // TResult is Task<TActual>; unwrap it, run the query synchronously and re-wrap.
            var resultType = typeof(TResult).GetGenericArguments()[0];
            var result = typeof(IQueryProvider)
                .GetMethods()
                .Single(m => m.Name == nameof(IQueryProvider.Execute) && m.IsGenericMethod)
                .MakeGenericMethod(resultType)
                .Invoke(inner, [expression]);

            return (TResult)typeof(Task)
                .GetMethod(nameof(Task.FromResult))!
                .MakeGenericMethod(resultType)
                .Invoke(null, [result])!;
        }
    }

    /// <remarks>
    /// Declared as <see cref="IOrderedQueryable{T}"/> as well as <see cref="IQueryable{T}"/>, because
    /// <c>Queryable.OrderBy</c> casts its own result to the ordered interface before returning it. A
    /// handler that sorts — which most of them do — otherwise fails in tests with an
    /// <c>InvalidCastException</c> that says nothing about ordering, while working perfectly against
    /// a real database. The interface adds no members; the sorting itself is the inner provider's.
    /// </remarks>
    private sealed class AsyncQueryable<T>(Expression expression, IQueryProvider provider)
        : IOrderedQueryable<T>, IAsyncEnumerable<T>
    {
        public Type ElementType => typeof(T);

        public Expression Expression => expression;

        public IQueryProvider Provider => provider;

        public IEnumerator<T> GetEnumerator() =>
            provider.Execute<IEnumerable<T>>(expression).GetEnumerator();

        IEnumerator IEnumerable.GetEnumerator() => GetEnumerator();

        public IAsyncEnumerator<T> GetAsyncEnumerator(CancellationToken cancellationToken = default) =>
            new AsyncEnumerator<T>(GetEnumerator());
    }

    private sealed class AsyncEnumerator<T>(IEnumerator<T> inner) : IAsyncEnumerator<T>
    {
        public T Current => inner.Current;

        public ValueTask<bool> MoveNextAsync() => ValueTask.FromResult(inner.MoveNext());

        public ValueTask DisposeAsync()
        {
            inner.Dispose();
            return ValueTask.CompletedTask;
        }
    }
}
