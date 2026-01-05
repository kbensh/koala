import pandas as pd
import numpy as np
from sklearn.decomposition import PCA
from sklearn.preprocessing import StandardScaler
import matplotlib.pyplot as plt
from adjustText import adjust_text

def perform_pca_and_plot(dataframe1, dataframe2, path='pca.pdf'):
    """
    Perform PCA on the numeric columns of two input dataframes and plots each pair of principal components
    (1&2 and 3&4) in a 2x2 grid, with one dataset per row and unified titles for each dataset.
    Each point is annotated with the corresponding benchmark name, avoiding label collisions.

    Parameters:
        dataframe1 (pd.DataFrame): First input dataframe.
        dataframe2 (pd.DataFrame): Second input dataframe.
        name (str): Name for saving the plots.

    Returns:
        tuple: Two dataframes containing the principal components for each input dataframe.
    """
    def prepare_pca(dataframe):
        # Ensure numeric columns are selected for PCA
        numeric_cols = dataframe.select_dtypes(include=[np.number]).columns
        if numeric_cols.empty:
            raise ValueError("No numeric columns available in the dataframe for PCA.")
        print(f"Numeric columns selected for PCA: {numeric_cols}")

        # Drop rows with NaN values in numeric columns and retain their indices for annotation
        dataframe_clean = dataframe.dropna(subset=numeric_cols)
        benchmark_names = dataframe_clean['benchmark'].values

        # Standardize the data
        scaler = StandardScaler()
        data_scaled = scaler.fit_transform(dataframe_clean[numeric_cols])

        # Perform PCA
        pca = PCA(n_components=4)  # Reduce to 4 components for analysis
        principal_components = pca.fit_transform(data_scaled)

        # Create a new dataframe with the principal components
        pca_df = pd.DataFrame(
            data=principal_components, 
            columns=['PC1', 'PC2', 'PC3', 'PC4']
        )

        # Print explained variance for each component
        print("\nExplained variance ratio:")
        for i, var_ratio in enumerate(pca.explained_variance_ratio_, start=1):
            print(f"PC{i}: {var_ratio:.2%}")

        # Print the component loadings
        print("\nPrincipal component loadings (contribution of each original feature):")
        loading_df = pd.DataFrame(
            pca.components_,
            columns=numeric_cols,
            index=[f'PC{i}' for i in range(1, 5)]
        )
        with pd.option_context('display.max_columns', None):
            print(loading_df)

        return pca_df, benchmark_names

    # Perform PCA on both dataframes
    pca_df1, benchmarks1 = prepare_pca(dataframe1)
    pca_df2, benchmarks2 = prepare_pca(dataframe2)

    # Create a 2x2 grid for the plots
    fig, axes = plt.subplots(2, 2, figsize=(12, 12), constrained_layout=True)

    big_size=22

    # Set the main titles for each dataset
    axes[0, 0].set_title('PCA from collected metrics', fontsize=big_size, loc='left')
    axes[1, 0].set_title('PCA from language model embeddings', fontsize=big_size, loc='left')

    # Helper function to plot and annotate
    def plot_with_labels(ax, x, y, labels, title, secondary=False):
        scatter = ax.scatter(x, y, c='black', alpha=0.7)
        # ax.set_title(title, fontsize=14, loc='left')
        ax.set_xlabel(f'Component {1 if not secondary else 3}', fontsize=big_size)
        ax.set_ylabel(f'Component {2 if not secondary else 4}', fontsize=big_size)
        ax.grid(color='lightgray', linestyle='--', linewidth=0.5)

        # Add text annotations
        texts = [ax.text(x[i], y[i], labels[i], fontsize=14, ha='center', va='center') for i in range(len(labels))]
        adjust_text(texts, ax=ax, arrowprops=dict(arrowstyle='-', color='gray', lw=0.5))

    # Plot Components 1 and 2 for Dataset 1
    plot_with_labels(
        axes[0, 0], 
        pca_df1['PC1'], 
        pca_df1['PC2'], 
        benchmarks1, 
        'PCA from collected metrics'
    )

    # Plot Components 3 and 4 for Dataset 1
    plot_with_labels(
        axes[0, 1], 
        pca_df1['PC3'], 
        pca_df1['PC4'], 
        benchmarks1, 
        '',
        True
    )

    # Plot Components 1 and 2 for Dataset 2
    plot_with_labels(
        axes[1, 0], 
        pca_df2['PC1'], 
        pca_df2['PC2'], 
        benchmarks2, 
        'PCA from language model embeddings'
    )

    # Plot Components 3 and 4 for Dataset 2
    plot_with_labels(
        axes[1, 1], 
        pca_df2['PC3'], 
        pca_df2['PC4'], 
        benchmarks2, 
        '',
        True
    )

    print(f"--------------------------")
    print(f"Saving PCA plot to {path}")
    print(f"--------------------------")
    # Save the plots
    plt.savefig(path, format='pdf')

    return pca_df1, pca_df2
