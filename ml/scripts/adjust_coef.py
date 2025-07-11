#!/usr/bin/env python3

import sys
import pickle
import numpy as np
import os

tmp = os.environ.get('OUT')
filepath = os.path.join(tmp, 'fold_coef.obj')
with open(filepath, 'rb') as file:
    fold_coefs_ = pickle.load(file)

model_file, X_file, multi_class, n_classes, destination = sys.argv[1:6]

n_classes = int(n_classes)

X = np.load(X_file)
n_features = X.shape[1]

with open(model_file, 'rb') as file:
    model = pickle.load(file)
    if multi_class == "multinomial":
        model.coef_ = fold_coefs_[0][0]
    else:
        model.coef_ = np.asarray(fold_coefs_)
        model.coef_ = model.coef_.reshape(
            n_classes, n_features + int(model.fit_intercept)
        )
    
    if model.fit_intercept:
        model.intercept_ = model.coef_[:, -1]
        model.coef_ = model.coef_[:, :-1]
    else:
        model.intercept_ = np.zeros(n_classes)

filepath = os.path.join(tmp, 'trained_model.obj')
with open(filepath, 'wb') as file:
    pickle.dump(model, file)