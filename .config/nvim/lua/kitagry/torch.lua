local vim = vim
local torch = require('torch')
local nn = require('nn')
local optim = require('optim')
local xlua = require('xlua')

local M = {}

function M.new()
  --confusion matrix用にクラスの定義
  local classes = {'1', '2', '3', '4', '5', '6', '7', '8', '9', '0'}
  --torch.Tensorのdefaultをtorch.FloatTensorに変更
  torch.setdefaulttensortype('torch.FloatTensor')

  local model = nn.Sequential()
  model:add(nn.View(32*32))
  model:add(nn.Linear(32*32, 1000)):add(nn.ReLU())
  model:add(nn.Linear(1000, 1000)):add(nn.ReLU())
  model:add(nn.Linear(1000, 10))
  model:add(nn.LogSoftMax())
  model = model:float()

  return {
    model=model,
    --loss関数の定義
    criterion = nn.ClassNLLCriterion(),
    --confusion matrixの定義(学習するだけなら必要なし)
    confusion = optim.ConfusionMatrix(#classes,classes),
    --最適化手法の定義
    optimizer = optim.adagrad,
    --最適化手法の初期値の指定(他の最適化手法の場合momentumやweightDecayなども必要となる場合がある)
    config = {learningRate = 0.001},

    load = function ()
      local trainData = torch.load(vim.env.HOME .. '/go/src/github.com/torch/tutorials/A_datasets/mnist.t7/train_32x32.t7', 'ascii')
      trainData.size = function () return trainData.data:size(1) end
      trainData.data = trainData.data:float()

      local testData = torch.load(vim.env.HOME .. '/go/src/github.com/torch/tutorials/A_datasets/mnist.t7/test_32x32.t7', 'ascii')
      testData.size = function () return testData.data:size(1) end
      testData.data = testData.data:float()

      return trainData, testData
    end,

    train = function(self, traindata, bsize)
      --学習対象のパラメータを取得
      local param, gparam = self.model:getParameters()

      print('training')
      self.model:training() --modelを学習モードに変更(これによりdropoutの有無が決まる)
      local shuffle = torch.randperm(traindata.data:size(1))

      print(traindata.data:size(2), traindata.data:size(3), traindata.data:size(4))
      for t = 1, traindata:size(), bsize do
        xlua.progress(t, traindata:size()) --progressbarを表示

        --入力サンプルとラベルの初期化
        local inputs = torch.FloatTensor(math.min(bsize, traindata:size()-t+1), traindata.data:size(2), traindata.data:size(3), traindata.data:size(4))
        local targets = torch.DoubleTensor(math.min(bsize, traindata:size()-t+1))

        for i = t, math.min(t+bsize-1,traindata:size()) do
          local input = traindata.data[shuffle[i]]
          local target = traindata.labels[shuffle[i]]
          inputs[i-t+1] = input
          targets[i-t+1] = target
        end

        local feval = function(x)
          -- get new parameters
          if x ~= param then
            param:copy(x)
          end

          gparam:zero()
          --forward
          local output = self.model:forward(inputs)
          local err = self.criterion:forward(output, targets) -- lossの計算
          --backward
          local df_do = self.criterion:backward(output, targets) -- loss関数の微分計算

          self.model:backward(inputs, df_do) -- 勾配のbackward
          --confusion matrixに結果を記述
          self.confusion:batchAdd(output:exp(), targets)

          return err, gparam
        end
        self.optimizer(feval, param, self.config)
      end
      print(self.confusion)
      --confusion matrixを初期化
      self.confusion:zero()
    end,

    test = function(self, testdata, bsize)
      self.model:evaluate() --評価モードに変更(dropoutの停止)
      print('testing')

      for t = 1, testdata:size(), bsize do
        xlua.progress(t, testdata:size())

        local inputs = testdata.data[{{t, math.min(t+bsize-1, testdata:size())},{},{},{}}]
        local targets = testdata.labels[{{t, math.min(t+bsize-1, testdata:size())}}]

        local output = self.model:forward(inputs)
        local err = self.criterion:forward(output, targets)
        print(err)

        self.confusion:batchAdd(output:exp(), targets)

      end

      print(self.confusion)
      self.confusion:zero()
    end
  }
end

return M
