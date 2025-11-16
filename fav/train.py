import random
import numpy as np
import torch
from torch import nn
import torch.nn.functional as F

import csv

class Model(nn.Module):
    def __init__(self):
        super(Model, self).__init__()

        self.l1 = nn.Linear(7, 32)
        self.l2 = nn.Linear(32, 32)
        self.l3 = nn.Linear(32, 1)

    def forward(self, x):
        x = F.relu(self.l1(x))
        x = F.relu(self.l2(x))
        x = F.softplus(self.l3(x))

        return x

def load_data(path):
    with open(path) as f:
        reader = csv.DictReader(f)
        return list(filter(None, map(fmt, reader)))

def fmt(d):
    if not d['aqi']:
        return None

    return (
        [
            float(d['lat']),
            float(d['lng']),
            # float(d['population']),
            float(d['flights']),
            float(d['aqi']),
            float(d['temp']),
            float(d['dew_pt']),
            float(d['dist'])
        ],
        [
            float(d['visit_rate'])
        ] if d['visit_rate'] else None,
        [
            d['city'],
            d['state'],
            d['state_long'],
            d['airport'],
            d['dist']
        ]
    )

train = load_data('train_output.csv')
random.shuffle(train)

use = [d for d in train if d[1]]

print(f'{len(use)} rows')

train = use[:80]
test = use[80:]

xs = np.array([row[0] for row in train], dtype=float)
mean = xs.mean(axis=0)
std = xs.std(axis=0) + 1e-8

def norm(xs):
    return (np.array(xs) - mean) / std

def train_model(train):
    model = Model()
    optim = torch.optim.Adam(model.parameters(), lr=1e-4)
    loss_fn = nn.MSELoss()

    epochs = 100
    load = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'

    for epoch in range(epochs):
        print(f'\r{load[(epoch // 5) % 10]} epoch {epoch + 1}', end='', flush=True)

        for xs, y, _ in train:
            out = model(torch.tensor(norm(xs), dtype=torch.float32).unsqueeze(0))
            loss = loss_fn(out, torch.tensor(y, dtype=torch.float32).unsqueeze(0))

            loss.backward()
            optim.step()
            optim.zero_grad()

    print()

    return model

# model = train_model(train)
# torch.save(model.state_dict(), 'weights.pth')

model = Model()
model.load_state_dict(torch.load('weights.pth'))
model.eval()

def eval_model(model, test):
    model.eval()
    total = 0.0

    with torch.no_grad():
        for xs, y, _ in test:
            pred = model(torch.tensor(norm(xs), dtype=torch.float32).unsqueeze(0))
            total += F.mse_loss(pred, torch.tensor(y, dtype=torch.float32).unsqueeze(0)).item()

    test_loss = total / len(test)
    print(f'loss: {test_loss}')

eval_model(model, test)

sample = load_data('sample_output.csv')

new = [
    (
        xs,
        [model(torch.tensor(norm(xs), dtype=torch.float32).unsqueeze(0)).item()],
        label
    )
    for xs, _, label in sample
]

header = [
    'city',
    'state',
    'state_long',
    'airport',
    # 'lat',
    # 'lng',
    # 'population',
    # 'flights',
    # 'aqi',
    # 'temp',
    # 'dew_pt',
    'dist',
    'visit_rate'
]

with open('pred.csv', 'w') as f:
    writer = csv.writer(f)
    writer.writerow(header)
    writer.writerows([row[2] + row[1] for row in new])
