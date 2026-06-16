import os
import streamlit as st
import pandas as pd
import altair as alt

st.set_page_config(
    page_title="Movie Analytics Dashboard",
    page_icon=":material/movie:",
    layout="wide",
)

conn = st.connection("snowflake", ttl=os.getenv("SNOWFLAKE_CONNECTION_TTL"))

st.title("Movie analytics dashboard", text_alignment="center")
st.caption("Comprehensive analytics across IMDb, MovieLens, Kaggle & Netflix")

DB = "MOVIE_PROJECT_DB"


@st.cache_data(ttl=600)
def run_query(sql):
    return conn.query(sql)


with st.sidebar:
    st.markdown(":material/movie: **Movie Analytics**")
    st.caption("Data sources: IMDb, MovieLens, Kaggle, Netflix")
    if st.button(":material/refresh: Refresh all data", use_container_width=True):
        run_query.clear()
        st.rerun()

tabs = st.tabs([
    ":material/trending_up: Popularity",
    ":material/category: Genres",
    ":material/attach_money: Financial",
    ":material/live_tv: Streaming",
    ":material/star: Ratings",
    ":material/recommend: Recommendations",
    ":material/group: Cast & Crew",
    ":material/analytics: Engagement",
    ":material/monitor_heart: Pipeline",
])

# =============================================================================
# TAB 1: Movie Popularity Analysis
# =============================================================================
with tabs[0]:
    st.header("Movie popularity analysis")

    col1, col2 = st.columns(2)
    with col1:
        with st.container(border=True):
            st.markdown("**Top 10 movies by IMDb rating**")
            df = run_query(f"SELECT TITLE, IMDB_RATING, NUMVOTES, RELEASE_YEAR FROM {DB}.GOLD.TOP_MOVIES_BY_RATING LIMIT 10")
            st.dataframe(
                df, hide_index=True,
                column_config={
                    "TITLE": st.column_config.TextColumn("Title", pinned=True),
                    "IMDB_RATING": st.column_config.NumberColumn("IMDb Rating", format="%.1f"),
                    "NUMVOTES": st.column_config.NumberColumn("Votes", format="%d"),
                    "RELEASE_YEAR": st.column_config.NumberColumn("Year", format="%d"),
                }
            )

    with col2:
        with st.container(border=True):
            st.markdown("**Top 10 movies by number of votes**")
            df = run_query(f"SELECT TITLE, NUMVOTES, IMDB_RATING, RELEASE_YEAR FROM {DB}.GOLD.TOP_MOVIES_BY_VOTES LIMIT 10")
            st.dataframe(
                df, hide_index=True,
                column_config={
                    "TITLE": st.column_config.TextColumn("Title", pinned=True),
                    "NUMVOTES": st.column_config.NumberColumn("Votes", format="%d"),
                    "IMDB_RATING": st.column_config.NumberColumn("Rating", format="%.1f"),
                    "RELEASE_YEAR": st.column_config.NumberColumn("Year", format="%d"),
                }
            )

    with st.container(border=True):
        st.markdown("**IMDb vs MovieLens rating comparison**")
        st.caption("Each dot is a movie rated on both platforms")
        merged = run_query(f"""
            SELECT TITLE, IMDB_RATING, MOVIELENS_RATING
            FROM {DB}.GOLD.IMDB_MOVIELENS_COMPARISON
            LIMIT 200
        """)
        if not merged.empty:
            st.scatter_chart(
                merged, x="IMDB_RATING", y="MOVIELENS_RATING",
                x_label="IMDb Rating (1-10)", y_label="MovieLens Rating (1-5)"
            )
        else:
            st.caption("No overlapping titles found.")

    with st.container(border=True):
        st.markdown("**Most popular movie per year**")
        year_filter = st.slider("Select year range", 1950, 2025, (2000, 2023), key="pop_year")
        df = run_query(f"""
            SELECT TITLE, RELEASE_YEAR, NUMVOTES, IMDB_RATING
            FROM {DB}.GOLD.MOST_POPULAR_BY_YEAR
            WHERE RELEASE_YEAR BETWEEN {year_filter[0]} AND {year_filter[1]}
            ORDER BY RELEASE_YEAR DESC
        """)
        st.dataframe(
            df, hide_index=True,
            column_config={
                "TITLE": st.column_config.TextColumn("Title", pinned=True),
                "RELEASE_YEAR": st.column_config.NumberColumn("Year", format="%d"),
                "NUMVOTES": st.column_config.NumberColumn("Votes", format="%d"),
                "IMDB_RATING": st.column_config.NumberColumn("Rating", format="%.1f"),
            }
        )

    with st.container(border=True):
        st.markdown("**Most popular movies by genre**")
        all_genres = run_query(f"SELECT DISTINCT GENRE FROM {DB}.GOLD.GENRE_BY_YEAR ORDER BY GENRE")
        selected_genre = st.selectbox("Select genre", all_genres["GENRE"].tolist(), key="pop_genre")
        genre_movies = run_query(f"""
            SELECT TITLE, IMDB_RATING, NUMVOTES, RELEASE_YEAR
            FROM {DB}.GOLD.IMDB_MOVIES_BY_GENRE
            WHERE GENRES LIKE '%{selected_genre}%'
            ORDER BY NUMVOTES DESC LIMIT 10
        """)
        st.dataframe(
            genre_movies, hide_index=True,
            column_config={
                "TITLE": st.column_config.TextColumn("Title", pinned=True),
                "IMDB_RATING": st.column_config.NumberColumn("Rating", format="%.1f"),
                "NUMVOTES": st.column_config.NumberColumn("Votes", format="%d"),
                "RELEASE_YEAR": st.column_config.NumberColumn("Year", format="%d"),
            }
        )

# =============================================================================
# TAB 2: Genre Performance Analysis
# =============================================================================
with tabs[1]:
    st.header("Genre performance analysis")

    genre_stats = run_query(f"""
        SELECT GENRE, SUM(MOVIE_COUNT) AS TOTAL_MOVIES, ROUND(AVG(AVG_RATING),2) AS AVG_RATING,
               ROUND(AVG(AVG_REVENUE),0) AS AVG_REVENUE, SUM(MOVIE_COUNT) AS TOTAL_VOTES
        FROM {DB}.GOLD.GENRE_BY_YEAR
        GROUP BY GENRE
        ORDER BY AVG_RATING DESC
    """)

    with st.container(horizontal=True):
        st.metric("Total genres", f"{len(genre_stats)}", border=True)
        st.metric("Highest rated", genre_stats.iloc[0]["GENRE"] if len(genre_stats) > 0 else "N/A", border=True)
        top_movies_genre = genre_stats.sort_values("TOTAL_MOVIES", ascending=False).iloc[0]["GENRE"] if len(genre_stats) > 0 else "N/A"
        st.metric("Most movies", top_movies_genre, border=True)

    col1, col2 = st.columns(2)
    with col1:
        with st.container(border=True):
            st.markdown("**Best performing genres by rating**")
            chart_df = genre_stats.head(15)[["GENRE", "AVG_RATING"]].sort_values("AVG_RATING", ascending=False)
            chart = alt.Chart(chart_df).mark_bar(cornerRadiusEnd=4).encode(
                x=alt.X("AVG_RATING:Q", title="Avg rating", scale=alt.Scale(domain=[0, 10])),
                y=alt.Y("GENRE:N", title="", sort="-x"),
                color=alt.value("#4A90D9")
            ).properties(height=400)
            st.altair_chart(chart)

    with col2:
        with st.container(border=True):
            st.markdown("**Highest revenue genres**")
            revenue_sorted = genre_stats.sort_values("AVG_REVENUE", ascending=False).head(15)[["GENRE", "AVG_REVENUE"]].copy()
            revenue_sorted["AVG_REVENUE_M"] = revenue_sorted["AVG_REVENUE"] / 1_000_000
            chart = alt.Chart(revenue_sorted).mark_bar(cornerRadiusEnd=4).encode(
                x=alt.X("AVG_REVENUE_M:Q", title="Avg revenue (millions $)"),
                y=alt.Y("GENRE:N", title="", sort="-x"),
                color=alt.value("#50C878")
            ).properties(height=400)
            st.altair_chart(chart)

    with st.container(border=True):
        st.markdown("**Genre trend by release year**")
        st.caption("Number of movies released per genre over time")
        genre_options = genre_stats["GENRE"].tolist()
        default_genres = [g for g in ["Drama", "Comedy", "Action"] if g in genre_options]
        selected_genres = st.multiselect("Select genres", genre_options, default=default_genres if default_genres else genre_options[:3], key="genre_trend")
        if selected_genres:
            genre_list = "','".join(selected_genres)
            genre_year = run_query(f"""
                SELECT GENRE, RELEASE_YEAR, MOVIE_COUNT
                FROM {DB}.GOLD.GENRE_BY_YEAR
                WHERE GENRE IN ('{genre_list}') AND RELEASE_YEAR BETWEEN 1980 AND 2023
                ORDER BY RELEASE_YEAR
            """)
            if not genre_year.empty:
                pivot = genre_year.pivot(index="RELEASE_YEAR", columns="GENRE", values="MOVIE_COUNT").fillna(0)
                st.area_chart(pivot, x_label="Year", y_label="Movies released")

    col3, col4 = st.columns(2)
    with col3:
        with st.container(border=True):
            st.markdown("**Total movies by genre**")
            runtime_df = genre_stats.head(15)[["GENRE", "TOTAL_MOVIES"]].copy()
            runtime_df.columns = ["GENRE", "AVG_RUNTIME"]
            chart = alt.Chart(runtime_df).mark_bar(cornerRadiusEnd=4).encode(
                x=alt.X("AVG_RUNTIME:Q", title="Total movies"),
                y=alt.Y("GENRE:N", title="", sort="-x"),
                color=alt.value("#FF8C42")
            ).properties(height=400)
            st.altair_chart(chart)
    with col4:
        with st.container(border=True):
            st.markdown("**Genre popularity (total votes)**")
            votes_df = genre_stats.sort_values("TOTAL_VOTES", ascending=False).head(15)[["GENRE", "TOTAL_VOTES"]].copy()
            votes_df["VOTES_K"] = votes_df["TOTAL_VOTES"] / 1_000
            chart = alt.Chart(votes_df).mark_bar(cornerRadiusEnd=4).encode(
                x=alt.X("VOTES_K:Q", title="Total votes (thousands)"),
                y=alt.Y("GENRE:N", title="", sort="-x"),
                color=alt.value("#9B59B6")
            ).properties(height=400)
            st.altair_chart(chart)

# =============================================================================
# TAB 3: Movie Financial Performance
# =============================================================================
with tabs[2]:
    st.header("Movie financial performance")

    fin_summary = run_query(f"""
        SELECT COUNT(*) AS TOTAL, ROUND(AVG(REVENUE),0) AS AVG_REV,
               ROUND(AVG(PROFIT),0) AS AVG_PROFIT, ROUND(MEDIAN(ROI),0) AS MED_ROI
        FROM {DB}.GOLD.MOVIE_FINANCIALS
    """)

    with st.container(horizontal=True):
        st.metric("Movies with financial data", f"{int(fin_summary.iloc[0]['TOTAL']):,}", border=True)
        st.metric("Avg revenue", f"${int(fin_summary.iloc[0]['AVG_REV']):,}", border=True)
        st.metric("Avg profit", f"${int(fin_summary.iloc[0]['AVG_PROFIT']):,}", border=True)
        st.metric("Median ROI", f"{int(fin_summary.iloc[0]['MED_ROI']):,}%", border=True)

    col1, col2 = st.columns(2)
    with col1:
        with st.container(border=True):
            st.markdown("**Highest revenue movies**")
            df = run_query(f"SELECT TITLE, REVENUE, BUDGET, PROFIT, RELEASE_YEAR FROM {DB}.GOLD.MOVIE_FINANCIALS ORDER BY REVENUE DESC LIMIT 10")
            st.dataframe(
                df, hide_index=True,
                column_config={
                    "TITLE": st.column_config.TextColumn("Title", pinned=True),
                    "REVENUE": st.column_config.NumberColumn("Revenue", format="$%d"),
                    "BUDGET": st.column_config.NumberColumn("Budget", format="$%d"),
                    "PROFIT": st.column_config.NumberColumn("Profit", format="$%d"),
                    "RELEASE_YEAR": st.column_config.NumberColumn("Year", format="%d"),
                }
            )

    with col2:
        with st.container(border=True):
            st.markdown("**Highest profit movies**")
            df = run_query(f"SELECT TITLE, PROFIT, REVENUE, BUDGET, RELEASE_YEAR FROM {DB}.GOLD.MOVIE_FINANCIALS ORDER BY PROFIT DESC LIMIT 10")
            st.dataframe(
                df, hide_index=True,
                column_config={
                    "TITLE": st.column_config.TextColumn("Title", pinned=True),
                    "PROFIT": st.column_config.NumberColumn("Profit", format="$%d"),
                    "REVENUE": st.column_config.NumberColumn("Revenue", format="$%d"),
                    "BUDGET": st.column_config.NumberColumn("Budget", format="$%d"),
                    "RELEASE_YEAR": st.column_config.NumberColumn("Year", format="%d"),
                }
            )

    with st.container(border=True):
        st.markdown("**Best ROI movies** (min budget $1M)")
        df = run_query(f"SELECT TITLE, ROI, BUDGET, REVENUE, PROFIT, RELEASE_YEAR FROM {DB}.GOLD.MOVIE_FINANCIALS WHERE BUDGET >= 1000000 ORDER BY ROI DESC LIMIT 10")
        st.dataframe(
            df, hide_index=True,
            column_config={
                "TITLE": st.column_config.TextColumn("Title", pinned=True),
                "ROI": st.column_config.NumberColumn("ROI", format="%.0f%%"),
                "BUDGET": st.column_config.NumberColumn("Budget", format="$%d"),
                "REVENUE": st.column_config.NumberColumn("Revenue", format="$%d"),
                "PROFIT": st.column_config.NumberColumn("Profit", format="$%d"),
                "RELEASE_YEAR": st.column_config.NumberColumn("Year", format="%d"),
            }
        )

    with st.container(border=True):
        st.markdown("**Budget vs revenue**")
        st.caption("Each dot represents a movie — higher above the diagonal = more profitable")
        scatter = run_query(f"SELECT BUDGET, REVENUE FROM {DB}.GOLD.MOVIE_FINANCIALS ORDER BY REVENUE DESC LIMIT 500")
        scatter["BUDGET_M"] = scatter["BUDGET"] / 1_000_000
        scatter["REVENUE_M"] = scatter["REVENUE"] / 1_000_000
        chart = alt.Chart(scatter).mark_circle(size=40, opacity=0.6).encode(
            x=alt.X("BUDGET_M:Q", title="Budget (millions $)"),
            y=alt.Y("REVENUE_M:Q", title="Revenue (millions $)"),
            color=alt.value("#4A90D9")
        ).properties(height=400)
        st.altair_chart(chart)

    with st.container(border=True):
        st.markdown("**Average revenue trend by year**")
        trend = run_query(f"""
            SELECT RELEASE_YEAR, ROUND(AVG(REVENUE),0) AS AVG_REVENUE
            FROM {DB}.GOLD.MOVIE_FINANCIALS
            WHERE RELEASE_YEAR BETWEEN 1980 AND 2023
            GROUP BY RELEASE_YEAR ORDER BY RELEASE_YEAR
        """)
        trend["AVG_REVENUE_M"] = trend["AVG_REVENUE"] / 1_000_000
        chart = alt.Chart(trend).mark_area(opacity=0.6, line=True).encode(
            x=alt.X("RELEASE_YEAR:O", title="Year"),
            y=alt.Y("AVG_REVENUE_M:Q", title="Avg revenue (millions $)"),
            color=alt.value("#50C878")
        ).properties(height=300)
        st.altair_chart(chart)

# =============================================================================
# TAB 4: Streaming Catalog Analysis (Netflix)
# =============================================================================
with tabs[3]:
    st.header("Streaming catalog analysis")
    st.caption("Netflix content library breakdown")

    summary = run_query(f"SELECT * FROM {DB}.GOLD.NETFLIX_CONTENT_SUMMARY")

    with st.container(horizontal=True):
        total = int(summary.iloc[0]["TOTAL_TITLES"])
        movies = int(summary.iloc[0]["MOVIES_COUNT"])
        tv = int(summary.iloc[0]["TV_SHOWS_COUNT"])
        st.metric("Total titles", f"{total:,}", border=True)
        st.metric("Movies", f"{movies:,}", border=True)
        st.metric("TV shows", f"{tv:,}", border=True)
        st.metric("Movie %", f"{movies/total*100:.0f}%", border=True)

    col1, col2 = st.columns(2)
    with col1:
        with st.container(border=True):
            st.markdown("**Movies vs TV shows**")
            type_df = pd.DataFrame({"TYPE": ["Movie", "TV Show"], "COUNT": [movies, tv]})
            st.bar_chart(type_df, x="TYPE", y="COUNT", x_label="Content type", y_label="Number of titles")

    with col2:
        with st.container(border=True):
            st.markdown("**Content added by year**")
            yearly = run_query(f"SELECT ADDED_YEAR AS YEAR, TITLES_ADDED AS COUNT FROM {DB}.GOLD.NETFLIX_ADDED_BY_YEAR WHERE ADDED_YEAR >= 2010 ORDER BY ADDED_YEAR")
            st.bar_chart(yearly, x="YEAR", y="COUNT", x_label="Year", y_label="Titles added")

    with st.container(border=True):
        st.markdown("**Top countries producing Netflix content**")
        countries = run_query(f"SELECT COUNTRY, TITLE_COUNT FROM {DB}.GOLD.NETFLIX_BY_COUNTRY LIMIT 15")
        chart = alt.Chart(countries).mark_bar(cornerRadiusEnd=4).encode(
            x=alt.X("TITLE_COUNT:Q", title="Number of titles"),
            y=alt.Y("COUNTRY:N", title="", sort="-x"),
            color=alt.value("#E74C3C")
        ).properties(height=400)
        st.altair_chart(chart)

    col3, col4 = st.columns(2)
    with col3:
        with st.container(border=True):
            st.markdown("**Genre distribution**")
            genres = run_query(f"SELECT GENRE, TITLE_COUNT FROM {DB}.GOLD.NETFLIX_BY_GENRE LIMIT 15")
            chart = alt.Chart(genres).mark_bar(cornerRadiusEnd=4).encode(
                x=alt.X("TITLE_COUNT:Q", title="Titles"),
                y=alt.Y("GENRE:N", title="", sort="-x"),
                color=alt.value("#9B59B6")
            ).properties(height=400)
            st.altair_chart(chart)

    with col4:
        with st.container(border=True):
            st.markdown("**Maturity rating distribution**")
            ratings = run_query(f"SELECT RATING, COUNT FROM {DB}.GOLD.NETFLIX_MATURITY_RATINGS ORDER BY COUNT DESC LIMIT 10")
            chart = alt.Chart(ratings).mark_bar(cornerRadiusEnd=4).encode(
                x=alt.X("COUNT:Q", title="Titles"),
                y=alt.Y("RATING:N", title="", sort="-x"),
                color=alt.value("#F39C12")
            ).properties(height=300)
            st.altair_chart(chart)

# =============================================================================
# TAB 5: User Rating Behavior
# =============================================================================
with tabs[4]:
    st.header("User rating behavior")

    stats = run_query(f"""
        SELECT SUM(RATING_COUNT) AS TOTAL_RATINGS,
               COUNT(*) AS UNIQUE_USERS,
               ROUND(SUM(RATING_COUNT * AVG_RATING) / SUM(RATING_COUNT), 2) AS AVG_RATING
        FROM {DB}.GOLD.USER_ACTIVITY
    """)

    with st.container(horizontal=True):
        st.metric("Total ratings", f"{int(stats.iloc[0]['TOTAL_RATINGS']):,}", border=True)
        st.metric("Unique users", f"{int(stats.iloc[0]['UNIQUE_USERS']):,}", border=True)
        st.metric("Average rating", f"{stats.iloc[0]['AVG_RATING']:.2f} / 5.0", border=True)

    with st.container(border=True):
        st.markdown("**Rating distribution**")
        st.caption("How users rate movies on a 0.5-5.0 scale")
        dist = run_query(f"SELECT * FROM {DB}.GOLD.USER_RATING_DISTRIBUTION")
        st.bar_chart(dist, x="RATING", y="RATING_COUNT", x_label="Rating", y_label="Number of ratings")

    col1, col2 = st.columns(2)
    with col1:
        with st.container(border=True):
            st.markdown("**Most rated movies**")
            df = run_query(f"SELECT TITLE, RATING_COUNT, ROUND(AVG_RATING,2) AS AVG_RATING FROM {DB}.GOLD.MOVIELENS_TOP_RATED ORDER BY RATING_COUNT DESC LIMIT 10")
            st.dataframe(
                df, hide_index=True,
                column_config={
                    "TITLE": st.column_config.TextColumn("Title", pinned=True),
                    "RATING_COUNT": st.column_config.NumberColumn("Ratings", format="%d"),
                    "AVG_RATING": st.column_config.NumberColumn("Avg rating", format="%.2f"),
                }
            )

    with col2:
        with st.container(border=True):
            st.markdown("**Users with highest rating activity**")
            df = run_query(f"SELECT USER_ID, RATING_COUNT, AVG_RATING FROM {DB}.GOLD.USER_ACTIVITY ORDER BY RATING_COUNT DESC LIMIT 10")
            st.dataframe(
                df, hide_index=True,
                column_config={
                    "USER_ID": st.column_config.NumberColumn("User ID", format="%d"),
                    "RATING_COUNT": st.column_config.NumberColumn("Ratings", format="%d"),
                    "AVG_RATING": st.column_config.NumberColumn("Avg rating", format="%.2f"),
                }
            )

    col3, col4 = st.columns(2)
    with col3:
        with st.container(border=True):
            st.markdown("**Average rating by year**")
            df = run_query(f"SELECT YEAR, AVG_RATING FROM {DB}.GOLD.RATINGS_BY_YEAR WHERE YEAR >= 2000 ORDER BY YEAR")
            chart = alt.Chart(df).mark_line(point=True, strokeWidth=2).encode(
                x=alt.X("YEAR:O", title="Year"),
                y=alt.Y("AVG_RATING:Q", title="Avg rating", scale=alt.Scale(domain=[3, 4])),
                color=alt.value("#E74C3C")
            ).properties(height=300)
            st.altair_chart(chart)

    with col4:
        with st.container(border=True):
            st.markdown("**Low-rated movies with high vote count**")
            df = run_query(f"SELECT TITLE, ROUND(AVG_RATING,2) AS AVG_RATING, RATING_COUNT FROM {DB}.GOLD.MOVIELENS_TOP_RATED WHERE AVG_RATING < 2.5 AND RATING_COUNT > 100 ORDER BY RATING_COUNT DESC LIMIT 10")
            st.dataframe(
                df, hide_index=True,
                column_config={
                    "TITLE": st.column_config.TextColumn("Title", pinned=True),
                    "AVG_RATING": st.column_config.NumberColumn("Avg rating", format="%.2f"),
                    "RATING_COUNT": st.column_config.NumberColumn("Ratings", format="%d"),
                }
            )

# =============================================================================
# TAB 6: Recommendation Analytics
# =============================================================================
with tabs[5]:
    st.header("Recommendation analytics")

    with st.container(border=True):
        st.markdown("**Recommended movies by genre**")
        st.caption("Top rated movies with 100+ ratings in selected genre")
        ml_genres = run_query(f"""
            SELECT GENRE FROM {DB}.GOLD.MOVIELENS_GENRE_LIST ORDER BY GENRE
        """)
        rec_genre = st.selectbox("Select genre for recommendations", ml_genres["GENRE"].tolist(), key="rec_genre")
        recs = run_query(f"""
            SELECT TITLE, AVG_RATING, RATING_COUNT, GENRES
            FROM {DB}.GOLD.MOVIELENS_TOP_RATED
            WHERE GENRES LIKE '%{rec_genre}%' AND RATING_COUNT >= 100
            ORDER BY AVG_RATING DESC LIMIT 10
        """)
        st.dataframe(
            recs, hide_index=True,
            column_config={
                "TITLE": st.column_config.TextColumn("Title", pinned=True),
                "AVG_RATING": st.column_config.NumberColumn("Rating", format="%.2f"),
                "RATING_COUNT": st.column_config.NumberColumn("Votes", format="%d"),
                "GENRES": st.column_config.TextColumn("Genres"),
            }
        )

    with st.container(border=True):
        st.markdown("**Top movies by tag**")
        st.caption("Movies most frequently tagged by users")
        top_tags = run_query(f"SELECT TAG, SUM(TAG_COUNT) AS TOTAL FROM {DB}.GOLD.MOVIES_BY_TAG GROUP BY TAG ORDER BY TOTAL DESC LIMIT 20")
        selected_tag = st.selectbox("Select tag", top_tags["TAG"].tolist(), key="rec_tag")
        tag_movies = run_query(f"SELECT TITLE, TAG_COUNT, UNIQUE_USERS FROM {DB}.GOLD.MOVIES_BY_TAG WHERE TAG = '{selected_tag}' ORDER BY TAG_COUNT DESC LIMIT 10")
        st.dataframe(
            tag_movies, hide_index=True,
            column_config={
                "TITLE": st.column_config.TextColumn("Title", pinned=True),
                "TAG_COUNT": st.column_config.NumberColumn("Tag count", format="%d"),
                "UNIQUE_USERS": st.column_config.NumberColumn("Users", format="%d"),
            }
        )

    col1, col2 = st.columns(2)
    with col1:
        with st.container(border=True):
            st.markdown("**Best movies: high rating & high votes**")
            st.caption("Rating >= 4.0, votes >= 500")
            df = run_query(f"SELECT TITLE, AVG_RATING, RATING_COUNT, GENRES FROM {DB}.GOLD.MOVIELENS_TOP_RATED WHERE AVG_RATING >= 4.0 AND RATING_COUNT >= 500 ORDER BY RATING_COUNT DESC LIMIT 15")
            st.dataframe(
                df, hide_index=True,
                column_config={
                    "TITLE": st.column_config.TextColumn("Title", pinned=True),
                    "AVG_RATING": st.column_config.NumberColumn("Rating", format="%.2f"),
                    "RATING_COUNT": st.column_config.NumberColumn("Votes", format="%d"),
                    "GENRES": st.column_config.TextColumn("Genres"),
                }
            )

    with col2:
        with st.container(border=True):
            st.markdown("**Hidden gems: high rating, low popularity**")
            st.caption("Rating >= 4.0, votes between 50-200")
            df = run_query(f"SELECT TITLE, AVG_RATING, RATING_COUNT, GENRES FROM {DB}.GOLD.MOVIELENS_TOP_RATED WHERE AVG_RATING >= 4.0 AND RATING_COUNT BETWEEN 50 AND 200 ORDER BY AVG_RATING DESC LIMIT 15")
            st.dataframe(
                df, hide_index=True,
                column_config={
                    "TITLE": st.column_config.TextColumn("Title", pinned=True),
                    "AVG_RATING": st.column_config.NumberColumn("Rating", format="%.2f"),
                    "RATING_COUNT": st.column_config.NumberColumn("Votes", format="%d"),
                    "GENRES": st.column_config.TextColumn("Genres"),
                }
            )

# =============================================================================
# TAB 7: Cast and Crew Analysis
# =============================================================================
with tabs[6]:
    st.header("Cast & crew analysis")

    cast_summary = run_query(f"""
        SELECT
            (SELECT COUNT(*) FROM {DB}.GOLD.ACTOR_PERFORMANCE) AS ACTORS,
            (SELECT COUNT(*) FROM {DB}.GOLD.DIRECTOR_PERFORMANCE) AS DIRECTORS
    """)

    with st.container(horizontal=True):
        st.metric("Unique actors", f"{int(cast_summary.iloc[0]['ACTORS']):,}", border=True)
        st.metric("Unique directors", f"{int(cast_summary.iloc[0]['DIRECTORS']):,}", border=True)

    col1, col2 = st.columns(2)
    with col1:
        with st.container(border=True):
            st.markdown("**Top actors by avg movie rating**")
            st.caption("Minimum 5 movies")
            df = run_query(f"SELECT PRIMARYNAME, MOVIE_COUNT, AVG_RATING FROM {DB}.GOLD.ACTOR_PERFORMANCE ORDER BY AVG_RATING DESC LIMIT 15")
            st.dataframe(
                df, hide_index=True,
                column_config={
                    "PRIMARYNAME": st.column_config.TextColumn("Actor", pinned=True),
                    "MOVIE_COUNT": st.column_config.NumberColumn("Movies", format="%d"),
                    "AVG_RATING": st.column_config.ProgressColumn("Avg rating", min_value=0, max_value=10, format="%.1f"),
                }
            )

    with col2:
        with st.container(border=True):
            st.markdown("**Top directors by avg rating**")
            st.caption("Minimum 3 movies")
            df = run_query(f"SELECT PRIMARYNAME, MOVIE_COUNT, AVG_RATING, TOTAL_VOTES FROM {DB}.GOLD.DIRECTOR_PERFORMANCE ORDER BY AVG_RATING DESC LIMIT 15")
            st.dataframe(
                df, hide_index=True,
                column_config={
                    "PRIMARYNAME": st.column_config.TextColumn("Director", pinned=True),
                    "MOVIE_COUNT": st.column_config.NumberColumn("Movies", format="%d"),
                    "AVG_RATING": st.column_config.ProgressColumn("Avg rating", min_value=0, max_value=10, format="%.1f"),
                    "TOTAL_VOTES": st.column_config.NumberColumn("Total votes", format="%d"),
                }
            )

    with st.container(border=True):
        st.markdown("**Top directors by total votes (popularity)**")
        df = run_query(f"SELECT PRIMARYNAME, MOVIE_COUNT, TOTAL_VOTES, AVG_RATING FROM {DB}.GOLD.DIRECTOR_PERFORMANCE ORDER BY TOTAL_VOTES DESC LIMIT 15")
        st.dataframe(
            df, hide_index=True,
            column_config={
                "PRIMARYNAME": st.column_config.TextColumn("Director", pinned=True),
                "MOVIE_COUNT": st.column_config.NumberColumn("Movies", format="%d"),
                "TOTAL_VOTES": st.column_config.NumberColumn("Total votes", format="%d"),
                "AVG_RATING": st.column_config.NumberColumn("Avg rating", format="%.1f"),
            }
        )

    with st.container(border=True):
        st.markdown("**Most frequent actor-director combinations**")
        df = run_query(f"SELECT ACTOR, DIRECTOR, MOVIES_TOGETHER, AVG_RATING FROM {DB}.GOLD.ACTOR_DIRECTOR_COMBOS ORDER BY MOVIES_TOGETHER DESC LIMIT 15")
        st.dataframe(
            df, hide_index=True,
            column_config={
                "ACTOR": st.column_config.TextColumn("Actor", pinned=True),
                "DIRECTOR": st.column_config.TextColumn("Director"),
                "MOVIES_TOGETHER": st.column_config.NumberColumn("Movies together", format="%d"),
                "AVG_RATING": st.column_config.NumberColumn("Avg rating", format="%.1f"),
            }
        )

# =============================================================================
# TAB 8: User Engagement Analytics
# =============================================================================
with tabs[7]:
    st.header("User engagement analytics")

    with st.container(border=True):
        st.markdown("**Most viewed/rated movies**")
        df = run_query(f"SELECT TITLE, RATING_COUNT AS VIEW_COUNT, AVG_RATING FROM {DB}.GOLD.MOVIELENS_TOP_RATED ORDER BY RATING_COUNT DESC LIMIT 15")
        st.dataframe(
            df, hide_index=True,
            column_config={
                "TITLE": st.column_config.TextColumn("Title", pinned=True),
                "VIEW_COUNT": st.column_config.NumberColumn("Ratings", format="%d"),
                "AVG_RATING": st.column_config.NumberColumn("Avg rating", format="%.2f"),
            }
        )

    col1, col2 = st.columns(2)
    with col1:
        with st.container(border=True):
            st.markdown("**Most tagged movies (watchlist proxy)**")
            df = run_query(f"SELECT TITLE, SUM(TAG_COUNT) AS TAG_COUNT, SUM(UNIQUE_USERS) AS UNIQUE_USERS FROM {DB}.GOLD.MOVIES_BY_TAG GROUP BY TITLE ORDER BY TAG_COUNT DESC LIMIT 15")
            st.dataframe(
                df, hide_index=True,
                column_config={
                    "TITLE": st.column_config.TextColumn("Title", pinned=True),
                    "TAG_COUNT": st.column_config.NumberColumn("Tags", format="%d"),
                    "UNIQUE_USERS": st.column_config.NumberColumn("Users", format="%d"),
                }
            )

    with col2:
        with st.container(border=True):
            st.markdown("**User activity by genre**")
            df = run_query(f"SELECT GENRE, RATING_COUNT FROM {DB}.GOLD.ENGAGEMENT_BY_GENRE LIMIT 15")
            df["RATINGS_K"] = df["RATING_COUNT"] / 1_000
            chart = alt.Chart(df).mark_bar(cornerRadiusEnd=4).encode(
                x=alt.X("RATINGS_K:Q", title="Ratings (thousands)"),
                y=alt.Y("GENRE:N", title="", sort="-x"),
                color=alt.value("#3498DB")
            ).properties(height=400)
            st.altair_chart(chart)

    with st.container(border=True):
        st.markdown("**Rating activity & active users by year**")
        df = run_query(f"SELECT YEAR, TOTAL_RATINGS, ACTIVE_USERS FROM {DB}.GOLD.RATINGS_BY_YEAR WHERE YEAR >= 2000 ORDER BY YEAR")
        df["RATINGS_K"] = df["TOTAL_RATINGS"] / 1_000
        df["USERS_K"] = df["ACTIVE_USERS"] / 1_000
        base = alt.Chart(df).encode(x=alt.X("YEAR:O", title="Year"))
        ratings_line = base.mark_area(opacity=0.4, color="#3498DB").encode(
            y=alt.Y("RATINGS_K:Q", title="Ratings (thousands)", axis=alt.Axis(titleColor="#3498DB"))
        )
        users_line = base.mark_line(strokeWidth=3, color="#E74C3C").encode(
            y=alt.Y("USERS_K:Q", title="Active users (thousands)", axis=alt.Axis(titleColor="#E74C3C"))
        )
        chart = alt.layer(ratings_line, users_line).resolve_scale(y="independent").properties(height=300)
        st.altair_chart(chart)

# =============================================================================
# TAB 9: Pipeline Monitoring
# =============================================================================
with tabs[8]:
    st.header("Pipeline monitoring")
    st.caption("Data quality checks across all source tables")

    pipeline_checks = run_query(f"SELECT * FROM {DB}.GOLD.PIPELINE_HEALTH")
    for col in ["ROW_COUNT", "NULL_KEY_FIELD", "NULL_SECONDARY_FIELD"]:
        pipeline_checks[col] = pd.to_numeric(pipeline_checks[col], errors="coerce")

    total_rows = pipeline_checks["ROW_COUNT"].sum()
    total_nulls = pipeline_checks["NULL_KEY_FIELD"].sum() + pipeline_checks["NULL_SECONDARY_FIELD"].sum()
    health_pct = ((total_rows - total_nulls) / total_rows * 100) if total_rows > 0 else 0

    with st.container(horizontal=True):
        st.metric("Total records", f"{total_rows:,.0f}", border=True)
        st.metric("NULL issues", f"{total_nulls:,.0f}", border=True)
        st.metric("Data health score", f"{health_pct:.2f}%", border=True)

    with st.container(border=True):
        st.markdown("**Pipeline source health**")
        st.dataframe(
            pipeline_checks, hide_index=True,
            column_config={
                "SOURCE_TABLE": st.column_config.TextColumn("Source", pinned=True),
                "ROW_COUNT": st.column_config.NumberColumn("Rows", format="%d"),
                "NULL_KEY_FIELD": st.column_config.NumberColumn("NULL (key)", format="%d"),
                "NULL_SECONDARY_FIELD": st.column_config.NumberColumn("NULL (secondary)", format="%d"),
            }
        )

    col1, col2 = st.columns(2)
    with col1:
        with st.container(border=True):
            st.markdown("**Records by source**")
            pc = pipeline_checks.copy()
            pc["ROWS_M"] = pc["ROW_COUNT"] / 1_000_000
            chart = alt.Chart(pc).mark_bar(cornerRadiusEnd=4).encode(
                x=alt.X("ROWS_M:Q", title="Rows (millions)"),
                y=alt.Y("SOURCE_TABLE:N", title="", sort="-x"),
                color=alt.value("#2ECC71")
            ).properties(height=250)
            st.altair_chart(chart)

    with col2:
        with st.container(border=True):
            st.markdown("**NULL issues by source**")
            null_df = pipeline_checks.melt(id_vars=["SOURCE_TABLE"], value_vars=["NULL_KEY_FIELD", "NULL_SECONDARY_FIELD"], var_name="TYPE", value_name="COUNT")
            null_df["TYPE"] = null_df["TYPE"].replace({"NULL_KEY_FIELD": "Key field", "NULL_SECONDARY_FIELD": "Secondary field"})
            chart = alt.Chart(null_df).mark_bar(cornerRadiusEnd=4).encode(
                x=alt.X("COUNT:Q", title="NULL count"),
                y=alt.Y("SOURCE_TABLE:N", title="", sort="-x"),
                color=alt.Color("TYPE:N", title="Field type", scale=alt.Scale(range=["#E74C3C", "#F39C12"]))
            ).properties(height=250)
            st.altair_chart(chart)

    with st.container(border=True):
        st.markdown("**Duplicate record check**")
        dup_checks = run_query(f"SELECT * FROM {DB}.GOLD.PIPELINE_DUPLICATES")
        st.dataframe(
            dup_checks, hide_index=True,
            column_config={
                "SOURCE": st.column_config.TextColumn("Source", pinned=True),
                "DUPLICATE_COUNT": st.column_config.NumberColumn("Duplicates", format="%d"),
            }
        )
