<?php
/**
 * Single Post Template - GeneratePress Child Theme
 * Affiche un article avec un design moderne et une navigation article précédent/suivant
 */

get_header();
?>

<div class="container">
    <div class="content-area">
        <main class="site-main">
            <?php
            while ( have_posts() ) {
                the_post();
                ?>
                <article id="post-<?php the_ID(); ?>" <?php post_class( 'modern-article' ); ?>>

                    <!-- En-tête de l'article -->
                    <header class="entry-header">
                        <div class="entry-meta-top">
                            <span class="entry-date">
                                <time datetime="<?php echo esc_attr( get_the_date( 'c' ) ); ?>">
                                    <?php echo esc_html( get_the_date( 'd F Y' ) ); ?>
                                </time>
                            </span>
                            <span class="entry-author">
                                <?php echo esc_html( __( 'Par', 'generatepress' ) ); ?>
                                <?php the_author(); ?>
                            </span>
                            <?php
                            $categories = get_the_category();
                            if ( ! empty( $categories ) ) {
                                echo '<span class="entry-categories">';
                                foreach ( $categories as $category ) {
                                    echo '<a href="' . esc_url( get_category_link( $category->term_id ) ) . '" class="category-badge">' . esc_html( $category->name ) . '</a>';
                                }
                                echo '</span>';
                            }
                            ?>
                        </div>

                        <?php
                        if ( has_post_thumbnail() ) {
                            ?>
                            <div class="entry-featured-image">
                                <?php the_post_thumbnail( 'large', array( 'class' => 'responsive-img' ) ); ?>
                            </div>
                            <?php
                        }
                        ?>

                        <h1 class="entry-title">
                            <?php the_title(); ?>
                        </h1>
                    </header>

                    <!-- Contenu de l'article -->
                    <div class="entry-content">
                        <?php
                        the_content(
                            sprintf(
                                wp_kses(
                                    /* translators: %s: Name of current post. Only visible to screen readers */
                                    __( 'Continue reading<span class="screen-reader-text"> "%s"</span>', 'generatepress' ),
                                    array(
                                        'span' => array(
                                            'class' => array(),
                                        ),
                                    )
                                ),
                                wp_kses_post( get_the_title() )
                            )
                        );

                        wp_link_pages(
                            array(
                                'before' => '<div class="page-links">' . esc_html__( 'Pages:', 'generatepress' ),
                                'after'  => '</div>',
                            )
                        );
                        ?>
                    </div>

                    <!-- Tags et partage -->
                    <footer class="entry-footer">
                        <div class="entry-tags">
                            <?php
                            $tags = get_the_tags();
                            if ( ! empty( $tags ) ) {
                                echo '<div class="tag-list">';
                                foreach ( $tags as $tag ) {
                                    echo '<a href="' . esc_url( get_tag_link( $tag->term_id ) ) . '" class="tag-badge">#' . esc_html( $tag->name ) . '</a>';
                                }
                                echo '</div>';
                            }
                            ?>
                        </div>

                        <!-- Partage social -->
                        <div class="social-share">
                            <?php
                            $post_url = urlencode( get_permalink() );
                            $post_title = urlencode( get_the_title() );
                            $excerpt = urlencode( wp_strip_all_tags( get_the_excerpt() ) );
                            ?>
                            <span class="share-label"><?php echo esc_html__( 'Partager:', 'generatepress' ); ?></span>
                            <a href="https://www.facebook.com/sharer/sharer.php?u=<?php echo $post_url; ?>" class="social-link facebook" target="_blank" rel="noopener noreferrer" title="Facebook">
                                <span class="icon">f</span>
                            </a>
                            <a href="https://x.com/intent/tweet?url=<?php echo $post_url; ?>&text=<?php echo $post_title; ?>" class="social-link twitter" target="_blank" rel="noopener noreferrer" title="X (Twitter)">
                                <span class="icon">𝕏</span>
                            </a>
                            <a href="https://www.linkedin.com/sharing/share-offsite/?url=<?php echo $post_url; ?>" class="social-link linkedin" target="_blank" rel="noopener noreferrer" title="LinkedIn">
                                <span class="icon">in</span>
                            </a>
                            <a href="https://pinterest.com/pin/create/button/?url=<?php echo $post_url; ?>&description=<?php echo $excerpt; ?>" class="social-link pinterest" target="_blank" rel="noopener noreferrer" title="Pinterest">
                                <span class="icon">P</span>
                            </a>
                        </div>
                    </footer>

                </article>

                <!-- Navigation article précédent/suivant -->
                <nav class="navigation post-navigation" aria-label="<?php echo esc_attr__( 'Post Navigation', 'generatepress' ); ?>">
                    <div class="nav-links">
                        <?php
                        $prev_post = get_previous_post();
                        $next_post = get_next_post();

                        if ( $prev_post ) {
                            $prev_url = get_permalink( $prev_post );
                            $prev_title = get_the_title( $prev_post );
                            $prev_excerpt = wp_strip_all_tags( get_the_excerpt( $prev_post ) );
                            $prev_image = get_the_post_thumbnail_url( $prev_post, 'medium' );
                            ?>
                            <div class="nav-previous nav-post">
                                <a href="<?php echo esc_url( $prev_url ); ?>" class="nav-link-wrapper">
                                    <div class="nav-content">
                                        <span class="nav-label"><?php echo esc_html__( 'Article précédent', 'generatepress' ); ?></span>
                                        <h3 class="nav-title"><?php echo esc_html( $prev_title ); ?></h3>
                                        <p class="nav-excerpt"><?php echo wp_trim_words( $prev_excerpt, 15 ); ?></p>
                                    </div>
                                    <?php
                                    if ( $prev_image ) {
                                        echo '<div class="nav-image"><img src="' . esc_url( $prev_image ) . '" alt="' . esc_attr( $prev_title ) . '"></div>';
                                    }
                                    ?>
                                </a>
                            </div>
                            <?php
                        }

                        if ( $next_post ) {
                            $next_url = get_permalink( $next_post );
                            $next_title = get_the_title( $next_post );
                            $next_excerpt = wp_strip_all_tags( get_the_excerpt( $next_post ) );
                            $next_image = get_the_post_thumbnail_url( $next_post, 'medium' );
                            ?>
                            <div class="nav-next nav-post">
                                <a href="<?php echo esc_url( $next_url ); ?>" class="nav-link-wrapper">
                                    <?php
                                    if ( $next_image ) {
                                        echo '<div class="nav-image"><img src="' . esc_url( $next_image ) . '" alt="' . esc_attr( $next_title ) . '"></div>';
                                    }
                                    ?>
                                    <div class="nav-content">
                                        <span class="nav-label"><?php echo esc_html__( 'Article suivant', 'generatepress' ); ?></span>
                                        <h3 class="nav-title"><?php echo esc_html( $next_title ); ?></h3>
                                        <p class="nav-excerpt"><?php echo wp_trim_words( $next_excerpt, 15 ); ?></p>
                                    </div>
                                </a>
                            </div>
                            <?php
                        }
                        ?>
                    </div>
                </nav>

                <?php
            }

            // Si les commentaires sont activés, affiche la section des commentaires
            if ( comments_open() || get_comments_number() ) {
                comments_template();
            }
            ?>

        </main>
    </div>
</div>

<style>
/* ========================================
   Styles modernes pour les articles
   ======================================== */

.modern-article {
    max-width: 900px;
    margin: 2rem auto;
    background: #ffffff;
    border-radius: 12px;
    box-shadow: 0 2px 12px rgba(0, 0, 0, 0.08);
    overflow: hidden;
}

.entry-header {
    padding: 2rem;
    border-bottom: 1px solid #f0f0f0;
}

.entry-meta-top {
    display: flex;
    align-items: center;
    gap: 1.5rem;
    margin-bottom: 1.5rem;
    flex-wrap: wrap;
    font-size: 0.95rem;
    color: #666;
}

.entry-date {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-weight: 500;
}

.entry-date::before {
    content: '📅';
}

.entry-author {
    display: flex;
    align-items: center;
    gap: 0.5rem;
}

.entry-author::before {
    content: '👤';
}

.entry-categories {
    display: flex;
    gap: 0.5rem;
    flex-wrap: wrap;
}

.category-badge {
    display: inline-block;
    padding: 0.4rem 0.8rem;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
    border-radius: 20px;
    font-size: 0.85rem;
    font-weight: 500;
    text-decoration: none;
    transition: all 0.3s ease;
}

.category-badge:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
}

.entry-featured-image {
    margin: 1.5rem -2rem -2rem -2rem;
    width: calc(100% + 4rem);
}

.entry-featured-image .responsive-img {
    width: 100%;
    height: auto;
    display: block;
}

.entry-title {
    font-size: 2.2rem;
    line-height: 1.3;
    margin: 1rem 0 0 0;
    color: #1a1a1a;
    font-weight: 700;
}

.entry-content {
    padding: 2rem;
    font-size: 1.1rem;
    line-height: 1.8;
    color: #333;
}

.entry-content p {
    margin-bottom: 1.5rem;
}

.entry-content h2,
.entry-content h3 {
    margin-top: 2rem;
    margin-bottom: 1rem;
    color: #1a1a1a;
    font-weight: 700;
}

.entry-content h2 {
    font-size: 1.8rem;
}

.entry-content h3 {
    font-size: 1.4rem;
}

.entry-content a {
    color: #667eea;
    text-decoration: underline;
    transition: color 0.3s ease;
}

.entry-content a:hover {
    color: #764ba2;
}

.entry-content ul,
.entry-content ol {
    margin: 1.5rem 0 1.5rem 2rem;
}

.entry-content li {
    margin-bottom: 0.5rem;
}

.entry-content blockquote {
    padding: 1.5rem;
    margin: 2rem 0;
    border-left: 4px solid #667eea;
    background: #f8f9ff;
    border-radius: 0 8px 8px 0;
    font-style: italic;
    color: #555;
}

.entry-footer {
    padding: 2rem;
    border-top: 1px solid #f0f0f0;
    background: #f9f9f9;
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 2rem;
    flex-wrap: wrap;
}

.tag-list {
    display: flex;
    gap: 0.8rem;
    flex-wrap: wrap;
}

.tag-badge {
    display: inline-block;
    padding: 0.4rem 0.8rem;
    background: #e8eaf6;
    color: #667eea;
    border-radius: 20px;
    font-size: 0.85rem;
    text-decoration: none;
    transition: all 0.3s ease;
}

.tag-badge:hover {
    background: #667eea;
    color: white;
}

.social-share {
    display: flex;
    align-items: center;
    gap: 1rem;
}

.share-label {
    font-weight: 500;
    color: #666;
    font-size: 0.95rem;
}

.social-link {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 40px;
    height: 40px;
    border-radius: 50%;
    background: #e8eaf6;
    color: #667eea;
    text-decoration: none;
    font-weight: bold;
    transition: all 0.3s ease;
    font-size: 1.1rem;
}

.social-link:hover {
    background: #667eea;
    color: white;
    transform: translateY(-3px);
}

.social-link.facebook:hover {
    background: #1877f2;
}

.social-link.twitter:hover {
    background: #000;
}

.social-link.linkedin:hover {
    background: #0a66c2;
}

.social-link.pinterest:hover {
    background: #e60023;
}

/* ========================================
   Navigation article précédent/suivant
   ======================================== */

.post-navigation {
    max-width: 900px;
    margin: 3rem auto;
}

.nav-links {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
    gap: 2rem;
}

.nav-post {
    position: relative;
}

.nav-link-wrapper {
    display: flex;
    gap: 1.5rem;
    padding: 1.5rem;
    background: white;
    border: 2px solid #e0e0e0;
    border-radius: 12px;
    text-decoration: none;
    color: inherit;
    transition: all 0.3s ease;
    height: 100%;
}

.nav-link-wrapper:hover {
    border-color: #667eea;
    box-shadow: 0 8px 20px rgba(102, 126, 234, 0.2);
    transform: translateY(-4px);
}

.nav-label {
    display: block;
    font-size: 0.85rem;
    color: #999;
    text-transform: uppercase;
    letter-spacing: 1px;
    font-weight: 600;
    margin-bottom: 0.5rem;
}

.nav-title {
    font-size: 1.3rem;
    font-weight: 700;
    margin: 0 0 0.8rem 0;
    color: #1a1a1a;
    line-height: 1.3;
}

.nav-excerpt {
    margin: 0;
    font-size: 0.95rem;
    color: #666;
    line-height: 1.5;
}

.nav-image {
    flex-shrink: 0;
    width: 150px;
    height: 150px;
    border-radius: 8px;
    overflow: hidden;
    background: #f0f0f0;
}

.nav-image img {
    width: 100%;
    height: 100%;
    object-fit: cover;
}

.nav-previous .nav-link-wrapper {
    flex-direction: row;
}

.nav-next .nav-link-wrapper {
    flex-direction: row-reverse;
}

/* Responsive */
@media (max-width: 768px) {
    .entry-header,
    .entry-content,
    .entry-footer {
        padding: 1.5rem;
    }

    .entry-title {
        font-size: 1.8rem;
    }

    .entry-featured-image {
        margin: 1rem -1.5rem -1.5rem -1.5rem;
        width: calc(100% + 3rem);
    }

    .entry-footer {
        flex-direction: column;
        align-items: flex-start;
    }

    .nav-link-wrapper {
        flex-direction: column !important;
    }

    .nav-image {
        width: 100%;
        height: 200px;
    }

    .nav-links {
        grid-template-columns: 1fr;
    }

    .entry-meta-top {
        gap: 1rem;
    }

    .social-share {
        width: 100%;
    }
}

/* Thème sombre optionnel */
@media (prefers-color-scheme: dark) {
    .modern-article {
        background: #1e1e1e;
        box-shadow: 0 2px 12px rgba(0, 0, 0, 0.3);
    }

    .entry-header,
    .entry-footer {
        border-color: #333;
    }

    .entry-footer {
        background: #2a2a2a;
    }

    .entry-title,
    .entry-content h2,
    .entry-content h3,
    .nav-title {
        color: #e8e8e8;
    }

    .entry-content,
    .entry-meta-top {
        color: #ccc;
    }

    .entry-content blockquote {
        background: #2a2a2a;
        color: #aaa;
    }

    .nav-link-wrapper {
        background: #262626;
        border-color: #404040;
    }

    .tag-badge {
        background: #2a2a2a;
        color: #8ab4f8;
    }

    .tag-badge:hover {
        background: #667eea;
        color: white;
    }

    .social-link {
        background: #2a2a2a;
        color: #8ab4f8;
    }
}
</style>

<?php
get_footer();
